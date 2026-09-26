import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../core/network/normalizers.dart';
import '../../shared/formatters/formatters.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/states.dart';
import '../../app/providers.dart';

const Map<String, List<String>> resellerNextStatus = {
  'pending': ['confirmed', 'cancelled'],
  'confirmed': ['to_ship', 'ready_for_meetup', 'cancelled'],
  'to_ship': ['shipped', 'cancelled'],
  'ready_for_meetup': ['completed', 'cancelled'],
  'shipped': ['completed'],
};

class ResellerOrderScreen extends ConsumerStatefulWidget {
  const ResellerOrderScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<ResellerOrderScreen> createState() => _State();
}

class _State extends ConsumerState<ResellerOrderScreen> {
  bool _busy = false;
  String? _error;
  final _tracking = TextEditingController();

  @override
  void dispose() {
    _tracking.dispose();
    super.dispose();
  }

  Future<void> _advance(String nextStatus) async {
    setState(() => _error = null);
    if (nextStatus == 'shipped' && _tracking.text.trim().isEmpty) {
      setState(
        () => _error =
            'A tracking number is required when marking a group as shipped.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update status to ${statusLabel(nextStatus)}?'),
        content: const Text('This updates the assigned order group.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).updateResellerGroup(widget.id, {
        'status': nextStatus,
        if (nextStatus == 'shipped' && _tracking.text.trim().isNotEmpty)
          'tracking_number': _tracking.text.trim(),
      });
      ref.invalidate(resellerOrdersProvider);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(resellerOrdersProvider);
    return Scaffold(
      appBar: const MarketplaceAppBar(
        title: Text('Assigned order group'),
        backFallback: '/reseller/orders',
      ),
      body: orders.when(
        data: (list) {
          Map<String, dynamic>? match;
          for (final r in list) {
            if ((normInt(r['order_group_id'] ?? r['group_id'] ?? r['id']) ??
                    -1) ==
                widget.id) {
              match = r;
              break;
            }
          }
          if (match == null) {
            return const Center(
              child: Text('This order group is not assigned to you.'),
            );
          }
          return _body(context, match);
        },
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(resellerOrdersProvider),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> m) {
    final theme = Theme.of(context);
    final status = normStr(
      m['fulfillment_status'] ?? m['status'] ?? m['group_status'],
    );
    final store = normStr(m['store_name']) == ''
        ? 'Your store'
        : normStr(m['store_name']);
    final refNum = normStr(
      m['order_number'] ?? m['order_no'] ?? '#${widget.id}',
    );
    final allowed = resellerNextStatus[status] ?? const <String>[];
    final needsTracking = allowed.contains('shipped');
    final notes = normStr(m['order_notes'] ?? m['notes']);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Order $refNum', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('Seller: $store', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Status: ', style: theme.textTheme.titleMedium),
            StatusPill(status: status.isEmpty ? 'unknown' : status),
          ],
        ),
        const SizedBox(height: 16),
        Text('Buyer instructions', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          notes.isEmpty
              ? 'The buyer did not provide additional instructions.'
              : notes,
        ),
        const SizedBox(height: 16),
        FormErrorBanner(message: _error),
        const SizedBox(height: 8),
        if (needsTracking)
          TextField(
            controller: _tracking,
            decoration: const InputDecoration(
              labelText: 'Tracking number (required)',
              border: OutlineInputBorder(),
            ),
          ),
        if (needsTracking) const SizedBox(height: 12),
        Text('Allowed next statuses', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (allowed.isEmpty)
          const Text('This group is complete and has no further actions.')
        else
          for (final next in allowed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ActionButton(
                label: statusLabel(next),
                loading: _busy,
                icon: next == 'cancelled'
                    ? Icons.cancel_outlined
                    : Icons.arrow_forward,
                onPressed: () => _advance(next),
              ),
            ),
      ],
    );
  }
}
