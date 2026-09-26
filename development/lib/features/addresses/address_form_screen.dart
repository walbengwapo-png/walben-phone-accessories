import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/errors/api_exception.dart';
import '../../shared/widgets/controls.dart';

class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key});
  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipient = TextEditingController();
  final _phone = TextEditingController();
  final _street = TextEditingController();
  final _barangay = TextEditingController();
  final _zip = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();
  bool _isDefault = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _recipient.dispose();
    _phone.dispose();
    _street.dispose();
    _barangay.dispose();
    _zip.dispose();
    _city.dispose();
    _province.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).addAddress({
        'recipient_name': _recipient.text.trim(),
        'phone_number': _phone.text.trim(),
        'street': _street.text.trim(),
        if (_barangay.text.trim().isNotEmpty) 'barangay': _barangay.text.trim(),
        if (_zip.text.trim().isNotEmpty) 'zip_code': _zip.text.trim(),
        'city': _city.text.trim(),
        'province': _province.text.trim(),
        'is_default': _isDefault,
      });
      ref.invalidate(addressesProvider);
      if (mounted) context.go('/addresses');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MarketplaceAppBar(
        title: const Text('New address'),
        backFallback: '/addresses',
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => context.go('/addresses'),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormErrorBanner(message: _error),
                TextFormField(
                  controller: _recipient,
                  decoration: const InputDecoration(
                    labelText: 'Recipient name',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                  validator: _required,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _street,
                  decoration: const InputDecoration(
                    labelText: 'Street / address line',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _barangay,
                  decoration: const InputDecoration(
                    labelText: 'Barangay (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _zip,
                  decoration: const InputDecoration(
                    labelText: 'Zip code (optional)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _city,
                  decoration: const InputDecoration(labelText: 'City'),
                  validator: _required,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _province,
                  decoration: const InputDecoration(labelText: 'Province'),
                  validator: _required,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v),
                  title: const Text('Set as default address'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                ActionButton(
                  label: 'Save address',
                  loading: _submitting,
                  onPressed: _submit,
                  icon: Icons.check,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'This field is required.' : null;
}
