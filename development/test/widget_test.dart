import 'package:development/app/providers.dart';
import 'package:development/core/errors/api_exception.dart';
import 'package:development/core/network/api_client.dart';
import 'package:development/core/network/currency_client.dart';
import 'package:development/core/network/normalizers.dart';
import 'package:development/features/catalog/catalog_screen.dart';
import 'package:development/features/checkout/checkout_screen.dart';
import 'package:development/features/domain.dart';
import 'package:development/features/reseller/reseller_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test(
    'currency client requests PHP to USD and EUR rates and parses their date',
    () async {
      final paths = <String>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            paths.add(options.path);
            final quote = options.path.endsWith('USD') ? 'USD' : 'EUR';
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'base': 'PHP',
                  'quote': quote,
                  'date': '2026-09-25',
                  'rate': quote == 'USD' ? 0.016 : 0.014,
                },
              ),
            );
          },
        ),
      );
      final rates = await CurrencyClient(dio: dio).phpRates();
      expect(paths, containsAll(['/v2/rate/PHP/USD', '/v2/rate/PHP/EUR']));
      expect(rates.date, '2026-09-25');
      expect(rates.usd, 0.016);
      expect(rates.eur, 0.014);
    },
  );

  test('normInt handles int and numeric string forms', () {
    expect(normInt(5), equals(5));
    expect(normInt('12'), equals(12));
    expect(normInt(null), isNull);
  });

  test('normNum parses decimal strings', () {
    expect(normNum('9.99'), equals(9.99));
    expect(normNum(4), equals(4));
  });

  test('normBool normalizes boolean and numeric forms', () {
    expect(normBool('true'), isTrue);
    expect(normBool(1), isTrue);
    expect(normBool(0), isFalse);
    expect(normBool(false), isFalse);
  });

  test('normStrNull maps null-ish values to null', () {
    expect(normStrNull(null), isNull);
    expect(normStrNull('null'), isNull);
    expect(normStrNull('abc'), equals('abc'));
  });

  test('cart rows use snapshot price and variant stock', () {
    final cart = Cart.fromItems([
      {
        'id': '1',
        'product_id': '2',
        'name': 'Case',
        'price_snapshot': '49.50',
        'quantity': '2',
        'variant_stock': '3',
        'stock_quantity': '99',
      },
    ]);

    expect(cart.items.single.unitPrice, 49.5);
    expect(cart.items.single.stock, 3);
    expect(cart.subtotal, 99);
  });

  test('product list accepts the API main_image key', () {
    final product = Product.fromJson({
      'id': 1,
      'name': 'Cable',
      'base_price': '10',
      'stock_quantity': 4,
      'condition': 'new',
      'main_image': 'https://example.test/cable.jpg',
    });

    expect(product.imageUrls, ['https://example.test/cable.jpg']);
  });

  test('fulfillment status drives buyer and reseller status handling', () {
    final group = OrderGroup.fromJson({
      'id': '7',
      'fulfillment_status': 'to_ship',
    });

    expect(group.status, 'to_ship');
    expect(resellerNextStatus[group.status], contains('shipped'));
  });

  test('admin application parses applicant and document fields', () {
    final application = ResellerApplication.fromJson({
      'id': 4,
      'status': 'pending',
      'full_name': 'Ari Buyer',
      'email': 'ari@example.test',
      'phone_number': '09170000000',
      'document_url': 'https://example.test/document',
    });

    expect(application.applicantName, 'Ari Buyer');
    expect(application.applicantEmail, 'ari@example.test');
    expect(application.applicantPhone, '09170000000');
    expect(application.documentUrl, 'https://example.test/document');
  });

  test('envelope and list helpers reject malformed responses', () {
    expect(envelopeMap({'success': true})['success'], isTrue);
    expect(
      () => envelopeMap({'message': 'missing flag'}),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => mapList({
        'items': {'id': 1},
      }),
      throwsA(isA<ApiException>()),
    );
  });

  test('meet-up instructions require all four details', () {
    expect(validateMeetupInstructions(meetupInstructionsTemplate), isNotNull);
    expect(
      validateMeetupInstructions(
        'Location: Lobby\nDate: 2026-09-21\nTime: 3 PM\nInstructions: Call on arrival',
      ),
      isNull,
    );
    expect(
      validateMeetupInstructions(
        'Location: Lobby\nDate: \nTime: 3 PM\nInstructions: Call on arrival',
      ),
      contains('Date'),
    );
  });

  testWidgets(
    'catalog accepts an initial category query without lifecycle error',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = GoRouter(
        initialLocation: '/catalog?category=2',
        routes: [
          GoRoute(
            path: '/catalog',
            builder: (_, _) => const Scaffold(body: CatalogScreen()),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith(
              (ref) async => const [Category(id: 2, name: 'Cables')],
            ),
            brandsProvider.overrideWith((ref) async => const <Brand>[]),
            productsProvider.overrideWith(
              (ref, filter) async => const <Product>[],
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Cables'), findsOneWidget);
    },
  );
}
