import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/errors/api_exception.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/states.dart';
import '../domain.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailState();
}

class _ProductDetailState extends ConsumerState<ProductDetailScreen> {
  int? _selectedVariant;
  int _quantity = 1;
  bool _adding = false;
  String? _addError;

  int? _firstInStockId(Product p) {
    for (final v in p.variants) {
      if (v.stock > 0) return v.id;
    }
    return null;
  }

  int _maxFor(Product p, int? chosen) {
    if (p.variants.isEmpty) return p.stock;
    for (final v in p.variants) {
      if (v.id == chosen) return v.stock;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(productProvider(widget.id));
    return Scaffold(
      appBar: const MarketplaceAppBar(
        title: Text('Product'),
        backFallback: '/catalog',
      ),
      body: product.when(
        data: _body,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(productProvider(widget.id)),
        ),
      ),
    );
  }

  Widget _body(Product p) {
    final context = this.context;
    final theme = Theme.of(context);
    final chosen = _selectedVariant ?? _firstInStockId(p);
    final hasVariants = p.variants.isNotEmpty;
    final maxStock = _maxFor(p, chosen);
    final canAdd = p.status == 'active' && maxStock > 0;
    final qty = canAdd ? _quantity.clamp(1, maxStock) : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            height: 240,
            child: MarketplaceImage(
              url: p.imageUrls.isNotEmpty ? p.imageUrls.first : null,
              height: 240,
            ),
          ),
          const SizedBox(height: 12),
          Text(p.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '₱${p.price.toStringAsFixed(2)}',
            style: theme.textTheme.headlineSmall!.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          _CurrencyEstimate(price: p.price),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(status: p.condition.isEmpty ? 'new' : p.condition),
              StatusPill(status: p.isOfficial ? 'official' : 'reseller'),
              StatusPill(status: p.stock <= 0 ? 'out of stock' : 'in stock'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Seller: ${p.sellerName ?? (p.isOfficial ? 'Official Store' : 'Reseller')}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text('Description', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            p.description.isEmpty ? 'No description provided.' : p.description,
            style: theme.textTheme.bodyMedium,
          ),
          if (hasVariants) const SizedBox(height: 16),
          if (hasVariants)
            Text('Select variant', style: theme.textTheme.titleMedium),
          if (hasVariants) const SizedBox(height: 4),
          if (hasVariants)
            Wrap(
              spacing: 8,
              children: [
                for (final v in p.variants)
                  FilterChip(
                    label: Text(
                      v.stock <= 0 ? '${v.name} (out of stock)' : v.name,
                    ),
                    selected: chosen == v.id,
                    onSelected: v.stock > 0
                        ? (sel) {
                            if (sel) setState(() => _selectedVariant = v.id);
                          }
                        : null,
                  ),
              ],
            ),
          const SizedBox(height: 16),
          Text('Quantity', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Decrease',
                icon: const Icon(Icons.remove_circle_outlined),
                onPressed: () {
                  if (_quantity > 1) setState(() => _quantity -= 1);
                },
              ),
              Text('$qty', style: theme.textTheme.titleMedium),
              IconButton(
                tooltip: 'Increase',
                icon: const Icon(Icons.add_circle_outlined),
                onPressed: canAdd && _quantity < maxStock
                    ? () => setState(() => _quantity += 1)
                    : null,
              ),
              Text(
                'Available: ${maxStock < 0 ? 'unlimited' : maxStock}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          FormErrorBanner(message: _addError),
          const SizedBox(height: 8),
          ActionButton(
            label: canAdd ? 'Add to cart' : 'Out of stock',
            icon: Icons.add_shopping_cart,
            loading: _adding,
            onPressed: canAdd
                ? () => _addToCart(p, hasVariants ? chosen : null, maxStock)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart(Product p, int? variantId, int maxStock) async {
    setState(() => _addError = null);
    if (p.variants.isNotEmpty && variantId == null) {
      setState(() => _addError = 'Please select an in-stock variant.');
      return;
    }
    if (maxStock <= 0) {
      setState(() => _addError = 'This product is out of stock.');
      return;
    }
    final session = ref.read(sessionProvider).asData?.value;
    if (session == null) {
      context.go('/login?from=/products/${p.id}');
      return;
    }
    final qty = _quantity.clamp(1, maxStock > 0 ? maxStock : _quantity);
    setState(() => _adding = true);
    try {
      final payload = <String, dynamic>{'product_id': p.id, 'quantity': qty};
      if (variantId != null) payload['variant_id'] = variantId;
      await ref.read(repositoryProvider).addCart(payload);
      if (!mounted) return;
      ref.invalidate(cartProvider);
      ref.invalidate(productProvider(p.id));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Added to cart.')));
      context.go('/cart');
    } on ApiException catch (e) {
      if (mounted) setState(() => _addError = e.message);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }
}

class _CurrencyEstimate extends ConsumerWidget {
  const _CurrencyEstimate({required this.price});
  final num price;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rates = ref.watch(currencyRatesProvider);
    return rates.when(
      loading: () => const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Loading currency estimates…'),
        ],
      ),
      error: (_, _) => Row(
        children: [
          const Expanded(child: Text('Currency estimates unavailable.')),
          TextButton(
            onPressed: () => ref.invalidate(currencyRatesProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (rates) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Approx. \$${(price * rates.usd).toStringAsFixed(2)} USD / €${(price * rates.eur).toStringAsFixed(2)} EUR',
          ),
          Text(
            'Frankfurter rate date: ${rates.date} · Checkout in pesos',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
