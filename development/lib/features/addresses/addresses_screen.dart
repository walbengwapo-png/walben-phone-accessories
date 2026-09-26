import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/states.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);
    return Scaffold(
      appBar: const MarketplaceAppBar(
        title: Text('Saved addresses'),
        backFallback: '/account',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/addresses/new'),
        icon: const Icon(Icons.add),
        label: const Text('New address'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(addressesProvider.future),
        child: addresses.when(
          data: (list) => list.isEmpty
              ? ListView(
                  children: const [
                    EmptyView(
                      message:
                          'No saved addresses yet. Add one to use delivery.',
                    ),
                  ],
                )
              : ListView.separated(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final a = list[i];
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Row(
                        children: [
                          Flexible(child: Text(a.recipientName)),
                          if (a.isDefault) ...[
                            const SizedBox(width: 8),
                            const StatusChip(text: 'Default'),
                          ],
                        ],
                      ),
                      subtitle: Text(a.label),
                    );
                  },
                  separatorBuilder: (_, _) => const Divider(height: 1),
                ),
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: '$e',
            onRetry: () => ref.invalidate(addressesProvider),
          ),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 11),
      ),
    );
  }
}
