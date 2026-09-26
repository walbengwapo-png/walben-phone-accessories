import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/session/session.dart';
import '../../shared/formatters/formatters.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  String _roleLabel(UserSession session) {
    if (session.isAdmin) return 'Administrator';
    if (session.isApprovedReseller) return 'Approved reseller';
    final status = session.resellerStatus;
    if (status.isNotEmpty) {
      return 'Reseller application: ${statusLabel(status)}';
    }
    return 'Customer';
  }

  String _resellerEntryText(UserSession session) {
    final status = session.resellerStatus;
    if (status.isEmpty) return 'Apply to sell your own items.';
    if (status == 'pending') return 'Your application is under review.';
    if (status == 'rejected' || status == 'suspended') {
      return 'Review your application status.';
    }
    return 'Apply to start selling';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.asData?.value;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Account', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        if (user == null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'You are signed out.',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Sign in'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('Create account'),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                ),
              ),
              title: Text(user.name),
              subtitle: Text(_roleLabel(user)),
            ),
          ),
          const SizedBox(height: 8),
          if (!user.isApprovedReseller && !user.isAdmin) ...[
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Become a reseller'),
              subtitle: Text(_resellerEntryText(user)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/reseller/application'),
            ),
            const Divider(),
          ],
          if (user.isApprovedReseller) ...[
            ListTile(
              leading: const Icon(Icons.store_mall_directory_outlined),
              title: const Text('Reseller Center'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/reseller/center'),
            ),
            const Divider(),
          ],
          if (user.isAdmin) ...[
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Admin Console'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/admin'),
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Refresh session'),
            subtitle: const Text('Restore the latest profile state.'),
            onTap: () => ref.read(sessionProvider.notifier).refresh(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text(
                    'You will need to sign in again to place orders.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(sessionProvider.notifier).signOut();
                if (context.mounted) context.go('/home');
              }
            },
          ),
        ],
        const SizedBox(height: 24),
        Text('Phone Accessories Marketplace', style: theme.textTheme.bodySmall),
        Text(
          'P1 school demonstration build. Disposable test data only.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
