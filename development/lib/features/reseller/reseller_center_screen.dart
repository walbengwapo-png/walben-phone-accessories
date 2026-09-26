import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/controls.dart';

class ResellerCenterScreen extends StatelessWidget {
  const ResellerCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const MarketplaceAppBar(
        title: Text('Reseller Center'),
        backFallback: '/account',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Manage your inventory and fulfill assigned orders.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('My products'),
              subtitle: const Text('View and add your own products.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/reseller/products'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: const Text('Assigned orders'),
              subtitle: const Text('Fulfill the order groups assigned to you.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/reseller/orders'),
            ),
          ),
        ],
      ),
    );
  }
}
