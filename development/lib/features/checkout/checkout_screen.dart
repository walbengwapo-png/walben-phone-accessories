import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/errors/api_exception.dart';
import '../../core/network/normalizers.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/states.dart';
import '../domain.dart';

const meetupInstructionsTemplate = 'Location: \nDate: \nTime: \nInstructions: ';

/// Returns a message when a meet-up note does not contain all details needed
/// by the reseller to arrange the handoff.
String? validateMeetupInstructions(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'Enter the meet-up location, date, time, and instructions.';
  }
  for (final label in const ['Location', 'Date', 'Time', 'Instructions']) {
    final pattern = RegExp(
      '^$label[ \\t]*:[ \\t]*([^\\r\\n]+)[ \\t]*\$',
      multiLine: true,
    );
    final match = pattern.firstMatch(trimmed);
    if (match == null || (match.group(1)?.trim().isEmpty ?? true)) {
      return 'Complete the $label field in the meet-up instructions.';
    }
  }
  return null;
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutState();
}

class _CheckoutState extends ConsumerState<CheckoutScreen> {
  int _mode = 0; // 0 delivery, 1 meet-up
  int? _selectedAddressId;
  final _deliveryNotes = TextEditingController();
  final _meetupNotes = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _deliveryNotes.dispose();
    _meetupNotes.dispose();
    super.dispose();
  }

  void _setMode(int value) {
    if (value == 1 && _meetupNotes.text.trim().isEmpty) {
      _meetupNotes.text = meetupInstructionsTemplate;
    }
    setState(() => _mode = value);
  }

  Future<void> _placeOrder() async {
    final isDelivery = _mode == 0;
    if (isDelivery && _selectedAddressId == null) {
      setState(() => _error = 'Please select a delivery address.');
      return;
    }
    final notes = isDelivery
        ? _deliveryNotes.text.trim()
        : _meetupNotes.text.trim();
    final meetupError = isDelivery ? null : validateMeetupInstructions(notes);
    if (meetupError != null) {
      setState(() => _error = meetupError);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final order = await ref.read(repositoryProvider).checkout({
        'payment_method': 'cod_meetup',
        if (isDelivery) 'address_id': _selectedAddressId,
        if (notes.isNotEmpty) 'notes': notes,
      });
      if (!mounted) return;
      ref.invalidate(cartProvider);
      ref.invalidate(ordersProvider);
      ref.invalidate(productsProvider(const ProductFilter()));
      final orderId = normInt(order['id'] ?? order['order_id']) ?? 0;
      final orderNumber = normStr(
        order['order_number'] ?? order['order_no'] ?? '#$orderId',
      );
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Order placed'),
          content: Text(
            'Your order $orderNumber has been placed. It is payable on delivery or pick-up as chosen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) context.go(orderId > 0 ? '/orders/$orderId' : '/orders');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final addresses = ref.watch(addressesProvider);
    return Scaffold(
      appBar: MarketplaceAppBar(
        title: const Text('Checkout'),
        backFallback: '/cart',
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => context.go('/cart'),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: cart.when(
        data: (c) => _build(context, c, addresses),
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(cartProvider),
        ),
      ),
      bottomNavigationBar: cart.maybeWhen(
        data: (c) => c.items.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ActionButton(
                    label: 'Place COD / Meet-up order',
                    loading: _submitting,
                    onPressed: _placeOrder,
                    icon: Icons.receipt_long,
                  ),
                ),
              ),
        orElse: () => null,
      ),
    );
  }

  Widget _build(
    BuildContext context,
    Cart cart,
    AsyncValue<List<Address>> addresses,
  ) {
    final theme = Theme.of(context);
    final isDelivery = _mode == 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FormErrorBanner(message: _error),
        Text('Delivery or meet-up?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              label: Text('Delivery'),
              icon: Icon(Icons.local_shipping_outlined),
            ),
            ButtonSegment(
              value: 1,
              label: Text('Meet-up'),
              icon: Icon(Icons.person_pin_circle_outlined),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => _setMode(s.first),
        ),
        const SizedBox(height: 16),
        if (isDelivery)
          addresses.when(
            data: (list) => list.isEmpty
                ? Column(
                    children: [
                      const Text('No saved addresses. Add one to deliver.'),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => context.go('/addresses/new'),
                        child: const Text('Add address'),
                      ),
                    ],
                  )
                : RadioGroup<int>(
                    groupValue: _selectedAddressId,
                    onChanged: (value) =>
                        setState(() => _selectedAddressId = value),
                    child: Column(
                      children: [
                        for (final a in list)
                          RadioListTile<int>(
                            value: a.id,
                            title: Text(a.recipientName),
                            subtitle: Text(a.label),
                            secondary: a.isDefault
                                ? const StatusChipFromAddress()
                                : null,
                          ),
                      ],
                    ),
                  ),
            loading: () => const LoadingView(),
            error: (e, _) => Text('Could not load addresses: $e'),
          )
        else
          Text(
            'Meet-up: no delivery address is used. Provide the agreed meeting location and contact instructions in the notes below.',
            style: theme.textTheme.bodyMedium,
          ),
        const SizedBox(height: 16),
        TextFormField(
          controller: isDelivery ? _deliveryNotes : _meetupNotes,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: isDelivery
                ? 'Notes (optional)'
                : 'Meet-up instructions (required)',
            helperText: isDelivery
                ? null
                : 'Complete location, date, time, and handoff instructions.',
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        Text('Order summary', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _GroupedTotals(cart: cart),
        const SizedBox(height: 8),
        Text('Payment: COD / Meet-up', style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _GroupedTotals extends StatelessWidget {
  const _GroupedTotals({required this.cart});
  final Cart cart;
  @override
  Widget build(BuildContext context) {
    final official = cart.items.where((i) => i.isOfficial).toList();
    final resellers = cart.items.where((i) => !i.isOfficial).toList();
    final sections = [
      if (official.isNotEmpty) ('Official Store', official),
      if (resellers.isNotEmpty) ('Reseller order', resellers),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in sections)
          Text(entry.$1, style: Theme.of(context).textTheme.titleSmall),
        for (final entry in sections)
          for (final it in entry.$2)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '${it.quantity} × ${it.name} — ₱${it.lineTotal.toStringAsFixed(2)}',
              ),
            ),
        if (sections.isNotEmpty) const SizedBox(height: 4),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtotal'),
            Text(
              '₱${cart.subtotal.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const Text(
          'Shipping and total amount are set by the server when the order is placed.',
        ),
      ],
    );
  }
}

class StatusChipFromAddress extends StatelessWidget {
  const StatusChipFromAddress({super.key});
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
        'Default',
        style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 11),
      ),
    );
  }
}
