import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../shared/formatters/formatters.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/states.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(ordersProvider.future),
        child: orders.when(
          data: (list) => list.isEmpty
              ? ListView(children: const [EmptyView(message: 'No orders yet.')])
              : ListView.separated(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final o = list[i];
                    return ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(o.orderNumber),
                      subtitle: Row(
                        children: [
                          Expanded(
                            child: Text(
                              {
                                if (o.createdAt != null) localDate(o.createdAt),
                                if (o.totalAmount != null)
                                  ' • ₱${o.totalAmount!.toStringAsFixed(2)}',
                              }.join(' '),
                            ),
                          ),
                          StatusPill(status: o.status ?? 'placed'),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/orders/${o.id}'),
                    );
                  },
                  separatorBuilder: (_, _) => const Divider(),
                ),
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: '$e',
            onRetry: () => ref.invalidate(ordersProvider),
          ),
        ),
      ),
    );
  }
}
