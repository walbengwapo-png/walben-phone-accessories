import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/errors/api_exception.dart';
import '../../shared/widgets/states.dart';
import '../domain.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});
  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  // One mutation in flight per line id prevents rapid taps from racing.
  final Set<int> _inflight = {};
  final Map<int, String> _errors = {};

  Future<void> _mutate(int id, Future<void> Function() action) async {
    if (_inflight.contains(id)) return;
    setState(() => _inflight.add(id));
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(cartProvider);
      setState(() => _errors.remove(id));
    } on ApiException catch (e) {
      if (mounted) setState(() => _errors[id] = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errors[id] = 'Could not update the cart. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _inflight.remove(id));
    }
  }

  Future<void> _confirmRemove(CartItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove item?'),
        content: Text('Remove "${item.name}" from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!mounted || result != true) return;
    _mutate(item.id, () => ref.read(repositoryProvider).removeCart(item.id));
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: cart.when(
        data: (c) => _buildCart(context, c),
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(cartProvider),
        ),
      ),
      bottomNavigationBar: cart.maybeWhen(
        data: (c) => c.items.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () => context.go('/checkout'),
                    child: Text('Checkout (₱${c.subtotal.toStringAsFixed(2)})'),
                  ),
                ),
              ),
        orElse: () => null,
      ),
    );
  }

  Widget _buildCart(BuildContext context, Cart cart) {
    final official = cart.items.where((i) => i.isOfficial).toList();
    final resellers = cart.items.where((i) => !i.isOfficial).toList();
    final sections = <String, List<CartItem>>{
      'Official Store': official,
      'Reseller order': resellers,
    };
    final populated = sections.entries
        .where((e) => e.value.isNotEmpty)
        .toList();
    if (populated.isEmpty) {
      return const EmptyView(
        message: 'Your cart is empty. Browse the catalog to add items.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.refresh(cartProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final section in populated) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                section.key,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final item in section.value)
              _CartRow(
                item: item,
                busy: _inflight.contains(item.id),
                error: _errors[item.id],
                onIncrement: () => _mutate(
                  item.id,
                  () => ref
                      .read(repositoryProvider)
                      .updateCart(item.id, item.quantity + 1),
                ),
                onDecrement: () => _mutate(
                  item.id,
                  () => ref
                      .read(repositoryProvider)
                      .updateCart(item.id, item.quantity - 1),
                ),
                onRemove: () => _confirmRemove(item),
              ),
            const Divider(),
          ],
        ],
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({
    required this.item,
    required this.busy,
    this.error,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });
  final CartItem item;
  final bool busy;
  final String? error;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final stockOut = item.stockOut;
    final cap = item.availableQuantity;
    final canIncrement = !busy && !stockOut && (cap < 0 || item.quantity < cap);
    final canDecrement = !busy && item.quantity > 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: MarketplaceImage(url: item.imageUrl, height: 64),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (item.variantName != null &&
                          item.variantName!.isNotEmpty)
                        Text(
                          item.variantName!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      Text(
                        '₱${item.unitPrice.toStringAsFixed(2)} each',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Decrease',
                  onPressed: canDecrement ? onDecrement : null,
                ),
                Text(
                  '${item.quantity}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Increase',
                  onPressed: canIncrement ? onIncrement : null,
                ),
                const Spacer(),
                Text(
                  '₱${item.lineTotal.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (stockOut)
              Text(
                'Only ${item.stock} in stock, requested ${item.quantity}.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            if (error != null && error!.isNotEmpty)
              Text(
                error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: busy ? null : onRemove,
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
