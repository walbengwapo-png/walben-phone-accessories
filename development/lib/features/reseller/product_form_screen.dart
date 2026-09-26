import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/errors/api_exception.dart';
import '../../shared/widgets/controls.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, required this.official, this.productId});
  final bool official;
  final int? productId;
  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();
  int? _categoryId;
  int? _brandId;
  int _condition = 0;
  bool _submitting = false;
  String? _error;
  bool _loaded = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final price = num.tryParse(_price.text.trim());
    final stock = int.tryParse(_stock.text.trim());
    if (price == null ||
        !price.isFinite ||
        price < 0 ||
        price > 99999999.99 ||
        stock == null ||
        stock < 0) {
      setState(() => _error = 'Enter valid numbers for price and stock.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final payload = {
        'name': _name.text.trim(),
        if (_categoryId != null) 'category_id': _categoryId,
        if (_brandId != null) 'brand_id': _brandId,
        'description': _desc.text.trim(),
        'base_price': price,
        'stock_quantity': stock,
        if (!widget.official) 'condition': _condition == 0 ? 'new' : 'used',
      };
      final id = widget.productId;
      final repo = ref.read(repositoryProvider);
      final row = id == null
          ? (widget.official
                ? await repo.createOfficialProduct(payload)
                : await repo.createResellerProduct(payload))
          : <String, dynamic>{'id': id};
      if (id != null) {
        if (widget.official) {
          await repo.updateOfficialProduct(id, payload);
        } else {
          await repo.updateResellerProduct(id, payload);
        }
      }
      if (!mounted) return;
      ref.invalidate(resellerProductsProvider);
      ref.invalidate(adminProductsProvider);
      ref.invalidate(productProvider(id ?? 0));
      ref.invalidate(productsProvider);
      if (id != null) {
        context.go(widget.official ? '/admin/products' : '/reseller/products');
        return;
      }
      final p = row['product'];
      final createdId = (p is Map ? p['id'] : (row['id'] ?? row['product_id']));
      final idVal = createdId is int ? createdId : int.tryParse('$createdId');
      final returnPath = widget.official
          ? '/admin/products'
          : '/reseller/products';
      if (idVal != null) {
        context.go('/upload/$idVal?return=${Uri.encodeComponent(returnPath)}');
      } else {
        context.go(returnPath);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final managed = widget.productId == null
        ? null
        : (widget.official
              ? ref.watch(adminProductsProvider)
              : ref.watch(resellerProductsProvider));
    if (managed != null) {
      if (managed.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (managed.hasError) {
        return Scaffold(body: Center(child: Text('${managed.error}')));
      }
      final matches = managed.value!
          .where((p) => p.id == widget.productId)
          .toList();
      if (matches.isEmpty) {
        return const Scaffold(body: Center(child: Text('Product not found.')));
      }
      if (!_loaded) {
        final p = matches.first;
        _name.text = p.name;
        _desc.text = p.description;
        _price.text = p.price.toString();
        _stock.text = p.stock.toString();
        _categoryId = p.categoryId;
        _brandId = p.brandId;
        _condition = p.condition == 'used' ? 1 : 0;
        _loaded = true;
      }
    }
    final categories = ref.watch(categoriesProvider);
    final brands = ref.watch(brandsProvider);
    return Scaffold(
      appBar: MarketplaceAppBar(
        title: Text(
          widget.productId != null
              ? 'Edit product'
              : (widget.official ? 'New official product' : 'New product'),
        ),
        backFallback: widget.official
            ? '/admin/products'
            : '/reseller/products',
        actions: [
          TextButton(
            onPressed: _submitting
                ? null
                : () => context.go(
                    widget.official ? '/admin/products' : '/reseller/products',
                  ),
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
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Product name'),
                  validator: _required,
                ),
                const SizedBox(height: 16),
                categories.when(
                  data: (cats) => DropdownButtonFormField<int?>(
                    initialValue: _categoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Select a category'),
                      ),
                      for (final c in cats)
                        DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(c.name),
                        ),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                    validator: (v) => v == null ? 'Select a category.' : null,
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Could not load categories: $e'),
                ),
                const SizedBox(height: 16),
                brands.maybeWhen(
                  data: (list) => DropdownButtonFormField<int?>(
                    initialValue: _brandId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Brand (optional)',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('No brand'),
                      ),
                      for (final b in list)
                        DropdownMenuItem<int?>(
                          value: b.id,
                          child: Text(b.name),
                        ),
                    ],
                    onChanged: (v) => setState(() => _brandId = v),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _desc,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Base price (₱)',
                  ),
                  validator: (v) {
                    final price = num.tryParse(v?.trim() ?? '');
                    return price == null ||
                            !price.isFinite ||
                            price < 0 ||
                            price > 99999999.99
                        ? 'Enter a valid nonnegative peso price.'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _stock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Stock quantity',
                  ),
                  validator: (v) {
                    final stock = int.tryParse(v?.trim() ?? '');
                    return stock == null || stock < 0
                        ? 'Enter nonnegative whole stock.'
                        : null;
                  },
                ),
                if (!widget.official) const SizedBox(height: 16),
                if (!widget.official)
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('New')),
                      ButtonSegment(value: 1, label: Text('Used')),
                    ],
                    selected: {_condition},
                    onSelectionChanged: (s) =>
                        setState(() => _condition = s.first),
                  ),
                const SizedBox(height: 24),
                ActionButton(
                  label: widget.productId == null
                      ? 'Create product'
                      : 'Save changes',
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
