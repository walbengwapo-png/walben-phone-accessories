import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../shared/widgets/states.dart';
import '../domain.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});
  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  Timer? _debounce;
  String _search = '';
  int? _categoryId;
  int? _brandId;
  String? _lastCategoryParameter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final qp = GoRouterState.of(context).uri.queryParameters;
    final rawCategory = qp['category'];
    if (rawCategory == _lastCategoryParameter) return;
    _lastCategoryParameter = rawCategory;
    _categoryId = int.tryParse(rawCategory ?? '');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _search = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final brands = ref.watch(brandsProvider);
    final filter = ProductFilter(
      query: _search,
      categoryId: _categoryId,
      brandId: _brandId,
    );
    final products = ref.watch(productsProvider(filter));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(categoriesProvider);
        ref.invalidate(brandsProvider);
        ref.invalidate(productsProvider(filter));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      },
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            toolbarHeight: 68,
            title: const Text('Browse'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                onChanged: _onSearch,
                decoration: const InputDecoration(
                  hintText: 'Search the catalog',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: categories.when(
              data: (cats) {
                if (cats.isEmpty) return const SizedBox.shrink();
                return SizedBox(
                  height: 68,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(12),
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _categoryId == null,
                        onSelected: (_) => setState(() => _categoryId = null),
                      ),
                      for (final c in cats) ...[
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(c.name),
                          selected: _categoryId == c.id,
                          onSelected: (_) => setState(() => _categoryId = c.id),
                        ),
                      ],
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(height: 76, child: LoadingView()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(12),
                child: ErrorView(
                  message: '$e',
                  onRetry: () => ref.invalidate(categoriesProvider),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: brands.when(
              data: (list) {
                if (list.isEmpty) return const SizedBox.shrink();
                return SizedBox(
                  height: 68,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      ChoiceChip(
                        label: const Text('All brands'),
                        selected: _brandId == null,
                        onSelected: (_) => setState(() => _brandId = null),
                      ),
                      for (final b in list) ...[
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(b.name),
                          selected: _brandId == b.id,
                          onSelected: (_) => setState(() => _brandId = b.id),
                        ),
                      ],
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
            ),
          ),
          products.when(
            data: (list) => list.isEmpty
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      message: 'No products match your filters.',
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.all(12),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.68,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _ProductCardView(product: list[i]),
                        childCount: list.length,
                      ),
                    ),
                  ),
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: LoadingView(label: 'Loading products…'),
            ),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(productsProvider(filter)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCardView extends StatelessWidget {
  const _ProductCardView({required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/products/${product.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MarketplaceImage(
                url: product.imageUrls.isNotEmpty
                    ? product.imageUrls.first
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${product.price.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium!
                        .copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                  Text(
                    'Stock: ${product.stock < 0 ? 'N/A' : product.stock}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    product.isOfficial ? 'Official Store' : 'Reseller',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
