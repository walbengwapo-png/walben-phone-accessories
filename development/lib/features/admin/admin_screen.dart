import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/controls.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MarketplaceAppBar(
        title: Text('Admin Console'),
        backFallback: '/account',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Manage official products'),
              subtitle: const Text('View, edit, or delete official listings.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/admin/products'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Reseller applications'),
              subtitle: const Text('Approve, reject, or suspend sellers.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/admin/reseller-applications'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.add_business_outlined),
              title: const Text('Create official product'),
              subtitle: const Text('Add to the official catalog.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/admin/products/new'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('All orders'),
              subtitle: const Text('View the complete order list.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/admin/orders'),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Developer note',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'The order-group status override is unavailable until an authenticated admin '
                    'endpoint returns order group IDs (GET /admin/orders does not expose them). '
                    'No override control is shown to avoid using hard-coded group IDs.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
