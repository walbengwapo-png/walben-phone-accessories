import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/session/session.dart';
import '../../shared/formatters/formatters.dart';
import '../../shared/widgets/controls.dart';

class ResellerApplicationScreen extends ConsumerStatefulWidget {
  const ResellerApplicationScreen({super.key});
  @override
  ConsumerState<ResellerApplicationScreen> createState() => _AppState();
}

class _AppState extends ConsumerState<ResellerApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _store = TextEditingController();
  final _desc = TextEditingController();
  final _contact = TextEditingController();
  final _doc = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _store.dispose();
    _desc.dispose();
    _contact.dispose();
    _doc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).applyReseller({
        'store_name': _store.text.trim(),
        'store_description': _desc.text.trim(),
        'contact_number': _contact.text.trim(),
        if (_doc.text.trim().isNotEmpty) 'document_url': _doc.text.trim(),
      });
      await ref.read(sessionProvider.notifier).refresh();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final user = session.asData?.value;
    return Scaffold(
      appBar: MarketplaceAppBar(
        title: const Text('Reseller application'),
        backFallback: '/account',
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => context.go('/account'),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: _buildBody(context, user),
    );
  }

  Widget _buildBody(BuildContext context, UserSession? user) {
    final theme = Theme.of(context);
    final status = user?.resellerStatus ?? '';
    String? reason;
    if (user?.reseller is Map) {
      final r = user!.reseller as Map;
      final raw = r['reason'] ?? r['rejection_reason'];
      if (raw != null && '$raw'.isNotEmpty) reason = '$raw';
    }

    if (status == 'approved') {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_outlined, size: 48, color: Colors.green),
            const SizedBox(height: 12),
            const Text('You are an approved reseller.'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => context.go('/reseller/center'),
              child: const Text('Open Reseller Center'),
            ),
          ],
        ),
      );
    }
    if (status == 'pending') {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_top, size: 48),
            const SizedBox(height: 12),
            const Text('Your reseller application is under review.'),
          ],
        ),
      );
    }
    if (status == 'rejected' || status == 'suspended') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                'Application ${statusLabel(status)}.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (reason != null) const SizedBox(height: 8),
              if (reason != null)
                Text('Reason: $reason', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Apply to sell on the marketplace',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            FormErrorBanner(message: _error),
            TextFormField(
              controller: _store,
              decoration: const InputDecoration(labelText: 'Store name'),
              validator: _required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Store description',
                alignLabelWithHint: true,
              ),
              validator: _required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contact,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contact number'),
              validator: _required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _doc,
              decoration: const InputDecoration(
                labelText: 'Document URL (optional)',
              ),
            ),
            const SizedBox(height: 20),
            ActionButton(
              label: 'Submit application',
              loading: _submitting,
              onPressed: _submit,
              icon: Icons.send,
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'This field is required.' : null;
}
