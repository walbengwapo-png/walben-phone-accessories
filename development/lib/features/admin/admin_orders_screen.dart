import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../shared/formatters/formatters.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/states.dart';

class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(adminOrdersProvider);
    return Scaffold(
      appBar: const MarketplaceAppBar(
        title: Text('All orders'),
        backFallback: '/admin',
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'The admin list returns order and buyer fields only; group and fulfillment data are not exposed.',
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(adminOrdersProvider.future),
              child: orders.when(
                data: (list) => list.isEmpty
                    ? ListView(
                        children: const [EmptyView(message: 'No orders yet.')],
                      )
                    : ListView.separated(
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final o = list[i];
                          return ListTile(
                            leading: const Icon(Icons.receipt_long_outlined),
                            title: Text(o.orderNumber),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  o.buyerName ??
                                      o.buyerEmail ??
                                      'Unknown buyer',
                                ),
                                if (o.createdAt != null)
                                  Text(localDate(o.createdAt)),
                                if (o.notes != null && o.notes!.isNotEmpty)
                                  Text(
                                    'Notes: ${o.notes}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (o.totalAmount != null)
                                  Text(
                                    '₱${o.totalAmount!.toStringAsFixed(2)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                StatusPill(status: o.paymentStatus ?? 'unpaid'),
                              ],
                            ),
                          );
                        },
                        separatorBuilder: (_, _) => const Divider(),
                      ),
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  message: '$e',
                  onRetry: () => ref.invalidate(adminOrdersProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
