import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/network/normalizers.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/states.dart';

class ResellerOrdersScreen extends ConsumerWidget {
  const ResellerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(resellerOrdersProvider);
    return Scaffold(
      appBar: const MarketplaceAppBar(
        title: Text('Assigned orders'),
        backFallback: '/reseller/center',
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(resellerOrdersProvider.future),
        child: orders.when(
          data: (list) => list.isEmpty
              ? ListView(
                  children: const [
                    EmptyView(message: 'No orders are assigned to you yet.'),
                  ],
                )
              : ListView.separated(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final m = list[i];
                    final groupId = normInt(
                      m['order_group_id'] ?? m['group_id'] ?? m['id'],
                    );
                    if (groupId == null) return const SizedBox.shrink();
                    final status = normStr(
                      m['fulfillment_status'] ??
                          m['status'] ??
                          m['group_status'],
                    );
                    final refNum = normStr(
                      m['order_number'] ?? m['order_no'] ?? '#$groupId',
                    );
                    final hasInstructions = normStr(
                      m['order_notes'] ?? m['notes'],
                    ).isNotEmpty;
                    return ListTile(
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: Text('Order $refNum'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.group_outlined, size: 16),
                              const SizedBox(width: 4),
                              Text('Group #$groupId'),
                            ],
                          ),
                          if (hasInstructions)
                            const Row(
                              children: [
                                Icon(Icons.notes_outlined, size: 16),
                                SizedBox(width: 4),
                                Text('Buyer instructions available'),
                              ],
                            ),
                        ],
                      ),
                      trailing: StatusPill(
                        status: status.isEmpty ? 'unknown' : status,
                      ),
                      onTap: () => context.go('/reseller/orders/$groupId'),
                    );
                  },
                  separatorBuilder: (_, _) => const Divider(),
                ),
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: '$e',
            onRetry: () => ref.invalidate(resellerOrdersProvider),
          ),
        ),
      ),
    );
  }
}
