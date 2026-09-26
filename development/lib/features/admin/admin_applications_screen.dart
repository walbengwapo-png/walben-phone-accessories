import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/errors/api_exception.dart';
import '../../shared/formatters/formatters.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/states.dart';
import '../domain.dart';

class AdminApplicationsScreen extends ConsumerWidget {
  const AdminApplicationsScreen({super.key});

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    ResellerApplication app,
    String decision,
  ) async {
    final reasonController = TextEditingController();
    final storeName = app.storeName ?? 'N/A';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${statusLabel(decision)} application?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Store: $storeName'),
            if (decision == 'rejected') const SizedBox(height: 12),
            if (decision == 'rejected')
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (required)',
                  border: OutlineInputBorder(),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(statusLabel(decision)),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (!context.mounted || confirmed != true) return;
    if (decision == 'rejected' && reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A reason is required for rejection.')),
      );
      return;
    }
    try {
      await ref
          .read(repositoryProvider)
          .decideApplication(
            app.id,
            decision,
            decision == 'rejected' ? reason : null,
          );
      ref.invalidate(applicationsProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(applicationsProvider);
    return Scaffold(
      appBar: const MarketplaceAppBar(
        title: Text('Reseller applications'),
        backFallback: '/admin',
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(applicationsProvider.future),
        child: apps.when(
          data: (list) => list.isEmpty
              ? ListView(
                  children: const [
                    EmptyView(message: 'No reseller applications yet.'),
                  ],
                )
              : ListView.separated(
                  itemCount: list.length,
                  itemBuilder: (context, i) => _ApplicationCard(
                    app: list[i],
                    onDecide: (d) => _decide(context, ref, list[i], d),
                  ),
                  separatorBuilder: (_, _) => const Divider(),
                ),
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: '$e',
            onRetry: () => ref.invalidate(applicationsProvider),
          ),
        ),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.app, required this.onDecide});
  final ResellerApplication app;
  final void Function(String) onDecide;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  app.storeName ?? 'Unnamed store',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              StatusPill(status: app.status),
            ],
          ),
          if (app.storeDescription != null && app.storeDescription!.isNotEmpty)
            Text(
              app.storeDescription!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (app.contactNumber != null && app.contactNumber!.isNotEmpty)
            Text(
              'Contact: ${app.contactNumber}',
              style: theme.textTheme.bodySmall,
            ),
          if (app.applicantName != null && app.applicantName!.isNotEmpty)
            Text(
              'Applicant: ${app.applicantName}',
              style: theme.textTheme.bodySmall,
            ),
          if (app.applicantEmail != null && app.applicantEmail!.isNotEmpty)
            Text(
              'Email: ${app.applicantEmail}',
              style: theme.textTheme.bodySmall,
            ),
          if (app.applicantPhone != null && app.applicantPhone!.isNotEmpty)
            Text(
              'Applicant phone: ${app.applicantPhone}',
              style: theme.textTheme.bodySmall,
            ),
          if (app.documentUrl != null && app.documentUrl!.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text(
              'Document URL',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SelectableText(app.documentUrl!, style: theme.textTheme.bodySmall),
          ],
          if (app.rejectionReason != null && app.rejectionReason!.isNotEmpty)
            Text(
              'Reason: ${app.rejectionReason}',
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (app.status != 'approved')
                FilledButton.tonal(
                  onPressed: () => onDecide('approved'),
                  child: const Text('Approve'),
                ),
              if (app.status != 'rejected')
                OutlinedButton(
                  onPressed: () => onDecide('rejected'),
                  child: const Text('Reject'),
                ),
              if (app.status != 'suspended')
                TextButton(
                  onPressed: () => onDecide('suspended'),
                  child: const Text('Suspend'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
