import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/errors/api_exception.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/states.dart';
import '../domain.dart';

class ManagedProductsScreen extends ConsumerWidget {
  const ManagedProductsScreen({super.key, required this.official});
  final bool official;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(
      official ? adminProductsProvider : resellerProductsProvider,
    );
    final base = official ? '/admin/products' : '/reseller/products';
    return Scaffold(
      appBar: MarketplaceAppBar(
        title: Text(official ? 'Official products' : 'My products'),
        backFallback: official ? '/admin' : '/reseller/center',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('$base/new'),
        icon: const Icon(Icons.add),
        label: const Text('New product'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(
          official
              ? adminProductsProvider.future
              : resellerProductsProvider.future,
        ),
        child: products.when(
          data: (list) => list.isEmpty
              ? ListView(
                  children: const [
                    EmptyView(
                      message: 'No products yet. Add your first product.',
                    ),
                  ],
                )
              : ListView.separated(
                  itemCount: list.length,
                  itemBuilder: (context, i) =>
                      _Row(product: list[i], official: official),
                  separatorBuilder: (_, _) => const Divider(),
                ),
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: '$e',
            onRetry: () => ref.invalidate(
              official ? adminProductsProvider : resellerProductsProvider,
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends ConsumerStatefulWidget {
  const _Row({required this.product, required this.official});
  final Product product;
  final bool official;
  @override
  ConsumerState<_Row> createState() => _RowState();
}

class _RowState extends ConsumerState<_Row> {
  bool _deleting = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          'Remove "${widget.product.name}" from the catalog? Products with order history will be archived.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      final repo = ref.read(repositoryProvider);
      final result = widget.official
          ? await repo.deleteOfficialProduct(widget.product.id)
          : await repo.deleteResellerProduct(widget.product.id);
      if (!mounted) return;
      ref.invalidate(
        widget.official ? adminProductsProvider : resellerProductsProvider,
      );
      ref.invalidate(productProvider(widget.product.id));
      ref.invalidate(productsProvider);
      ref.invalidate(cartProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Product removed.'),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final base = widget.official ? '/admin/products' : '/reseller/products';
    return ListTile(
      leading: SizedBox(
        width: 56,
        height: 56,
        child: MarketplaceImage(
          url: product.imageUrls.isNotEmpty ? product.imageUrls.first : null,
          height: 56,
        ),
      ),
      title: Text(product.name),
      subtitle: Text(
        '₱${product.price.toStringAsFixed(2)} · Stock ${product.stock} · ${product.status}',
      ),
      onTap: product.status == 'active'
          ? () => context.go('/products/${product.id}')
          : null,
      trailing: _deleting
          ? const CircularProgressIndicator()
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit ${product.name}',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.go('$base/${product.id}/edit'),
                ),
                IconButton(
                  tooltip: 'Delete ${product.name}',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _delete,
                ),
              ],
            ),
    );
  }
}
