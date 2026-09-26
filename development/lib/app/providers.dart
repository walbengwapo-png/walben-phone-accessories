import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/currency_client.dart';
import '../core/session/session.dart';
import '../features/domain.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(tokenStoreProvider)),
);
final repositoryProvider = Provider<MarketplaceRepository>(
  (ref) => MarketplaceRepository(ref.watch(apiClientProvider)),
);
final currencyClientProvider = Provider<CurrencyClient>(
  (ref) => CurrencyClient(),
);
final currencyRatesProvider = FutureProvider.autoDispose<CurrencyRates>(
  (ref) => ref.watch(currencyClientProvider).phpRates(),
);

class SessionController extends AsyncNotifier<UserSession?> {
  @override
  Future<UserSession?> build() => restore();

  Future<UserSession?> restore() async {
    final token = await ref.read(tokenStoreProvider).accessToken();
    if (token == null) return null;
    try {
      final user = await ref.read(repositoryProvider).me();
      Map<String, dynamic>? application;
      try {
        application = await ref.read(repositoryProvider).resellerApplication();
      } catch (_) {}
      return UserSession(user: user, reseller: application);
    } catch (_) {
      return null;
    }
  }

  Future<void> signIn(Map<String, dynamic> auth) async {
    await ref
        .read(tokenStoreProvider)
        .save(auth['access_token'] as String, auth['refresh_token'] as String);
    final session = await restore();
    state = AsyncData(session);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(restore);
  }

  Future<void> signOut() async {
    try {
      await ref.read(repositoryProvider).logout();
    } finally {
      // Always clear the in-memory session, even if the remote logout failed.
      state = const AsyncData(null);
    }
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, UserSession?>(
  SessionController.new,
);

final categoriesProvider = FutureProvider.autoDispose<List<Category>>((
  ref,
) async {
  final rows = await ref.watch(repositoryProvider).categories();
  return rows.map(Category.fromJson).toList();
});

final brandsProvider = FutureProvider.autoDispose<List<Brand>>((ref) async {
  final rows = await ref.watch(repositoryProvider).brands();
  return rows.map(Brand.fromJson).toList();
});

final productsProvider = FutureProvider.autoDispose
    .family<List<Product>, ProductFilter>((ref, filter) async {
      final rows = await ref
          .watch(repositoryProvider)
          .products(q: filter.query, categoryId: filter.categoryId);
      var products = rows.map(Product.fromJson).toList();
      if (filter.brandId != null) {
        products = products.where((p) => p.brandId == filter.brandId).toList();
      }
      return products;
    });

final productProvider = FutureProvider.autoDispose.family<Product, int>((
  ref,
  id,
) async {
  final row = await ref.watch(repositoryProvider).product(id);
  return Product.fromJson(row);
});

final cartProvider = FutureProvider.autoDispose<Cart>((ref) async {
  final rows = await ref.watch(repositoryProvider).cart();
  return Cart.fromItems(rows);
});

final addressesProvider = FutureProvider.autoDispose<List<Address>>((
  ref,
) async {
  final rows = await ref.watch(repositoryProvider).addresses();
  final list = rows.map(Address.fromJson).toList()
    ..sort((a, b) => (b.isDefault ? 1 : 0).compareTo(a.isDefault ? 1 : 0));
  return list;
});

final ordersProvider = FutureProvider.autoDispose<List<BuyerOrder>>((
  ref,
) async {
  final rows = await ref.watch(repositoryProvider).orders();
  return rows.map(BuyerOrder.fromJson).toList();
});

final orderProvider = FutureProvider.autoDispose.family<BuyerOrder, int>((
  ref,
  id,
) async {
  final row = await ref.watch(repositoryProvider).order(id);
  return BuyerOrder.fromJson(row);
});

final resellerProductsProvider = FutureProvider.autoDispose<List<Product>>((
  ref,
) async {
  final rows = await ref.watch(repositoryProvider).resellerProducts();
  return rows.map(Product.fromJson).toList();
});

final adminProductsProvider = FutureProvider.autoDispose<List<Product>>((
  ref,
) async {
  final rows = await ref.watch(repositoryProvider).adminProducts();
  return rows.map(Product.fromJson).toList();
});

/// Assigned reseller order-group summary rows. Shape is server-dependent, so
/// rows are exposed as maps and normalized defensively in the reseller screens.
final resellerOrdersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(repositoryProvider).resellerOrders(),
    );

final applicationsProvider =
    FutureProvider.autoDispose<List<ResellerApplication>>((ref) async {
      final rows = await ref.watch(repositoryProvider).applications();
      return rows.map(ResellerApplication.fromJson).toList();
    });

final adminOrdersProvider = FutureProvider.autoDispose<List<AdminOrder>>((
  ref,
) async {
  final rows = await ref.watch(repositoryProvider).adminOrders();
  return rows.map(AdminOrder.fromJson).toList();
});

class ProductFilter {
  const ProductFilter({this.query = '', this.categoryId, this.brandId});
  final String query;
  final int? categoryId;
  final int? brandId;
  @override
  bool operator ==(Object other) =>
      other is ProductFilter &&
      other.query == query &&
      other.categoryId == categoryId &&
      other.brandId == brandId;
  @override
  int get hashCode => Object.hash(query, categoryId, brandId);
}
