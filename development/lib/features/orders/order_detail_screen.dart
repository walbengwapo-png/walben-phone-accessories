import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../shared/formatters/formatters.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/states.dart';
import '../domain.dart';
import '../../app/providers.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailState();
}

class _OrderDetailState extends ConsumerState<OrderDetailScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(orderProvider(widget.id));
      ref.invalidate(ordersProvider);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return r == true;
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderProvider(widget.id));
    return Scaffold(
      appBar: const MarketplaceAppBar(
        title: Text('Order'),
        backFallback: '/orders',
      ),
      body: order.when(
        data: (o) => _body(context, o),
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(orderProvider(widget.id)),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, BuyerOrder o) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FormErrorBanner(message: _error),
        Text(o.orderNumber, style: theme.textTheme.headlineSmall),
        if (o.createdAt != null)
          Text(localDate(o.createdAt), style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        if (o.notes != null && o.notes!.isNotEmpty)
          Text('Notes', style: theme.textTheme.titleMedium),
        if (o.notes != null && o.notes!.isNotEmpty) Text(o.notes!),
        if (o.wasDelivery)
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined),
              const SizedBox(width: 6),
              Text('Delivery order', style: theme.textTheme.bodyMedium),
            ],
          ),
        const SizedBox(height: 12),
        Text(
          'Orders are tracked per seller. Each seller group has its own status.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (o.groups.isEmpty)
          const Text('No seller groups are attached to this order.')
        else
          for (final g in o.groups)
            _GroupCard(
              order: o,
              group: g,
              busy: _busy,
              onCancel: () async {
                if (await _confirm(
                  'Cancel order?',
                  'Cancel this pending seller group?',
                )) {
                  _run(() => ref.read(repositoryProvider).cancelGroup(g.id));
                }
              },
              onReceive: () async {
                if (await _confirm(
                  'Received?',
                  'Confirm you received this group?',
                )) {
                  _run(() => ref.read(repositoryProvider).receivedGroup(g.id));
                }
              },
            ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total', style: theme.textTheme.titleMedium),
            Text(
              o.totalAmount?.toStringAsFixed(2) ?? '—',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.order,
    required this.group,
    required this.busy,
    required this.onCancel,
    required this.onReceive,
  });
  final BuyerOrder order;
  final OrderGroup group;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onReceive;

  @override
  Widget build(BuildContext context) {
    final status = group.status;
    final canCancel = status == 'pending' && !busy;
    final shipped = status == 'shipped';
    final readyMeetup = status == 'ready_for_meetup';
    final canReceive = (shipped || readyMeetup) && !busy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.displaySeller,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                StatusPill(status: status),
              ],
            ),
            if (group.trackingNumber != null &&
                group.trackingNumber!.isNotEmpty)
              Text(
                'Tracking: ${group.trackingNumber}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (canCancel)
              TextButton(
                onPressed: onCancel,
                child: const Text('Cancel this group'),
              ),
            if (canReceive)
              TextButton(onPressed: onReceive, child: const Text('Received')),
          ],
        ),
      ),
    );
  }
}
