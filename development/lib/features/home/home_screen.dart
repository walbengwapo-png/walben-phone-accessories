import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../shared/widgets/states.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.asData?.value;
    final categories = ref.watch(categoriesProvider);
    final products = ref.watch(productsProvider(const ProductFilter()));
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        ref.refresh(categoriesProvider.future),
        ref.refresh(productsProvider(const ProductFilter()).future),
      ]),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Phone Accessories Marketplace',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            user == null
                ? 'Hello, guest. Browse the catalog or sign in.'
                : 'Hello, ${user.name}.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          if (user == null)
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Sign in'),
                ),
                FilledButton.tonal(
                  onPressed: () => context.go('/register'),
                  child: const Text('Create account'),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Text('Shop by category', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          categories.when(
            data: (cats) => cats.isEmpty
                ? const EmptyView(message: 'No categories available yet.')
                : SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: cats.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => _CategoryCard(
                        name: cats[i].name,
                        onTap: () =>
                            context.go('/catalog?category=${cats[i].id}'),
                      ),
                    ),
                  ),
            loading: () => const LoadingView(label: 'Loading categories…'),
            error: (e, _) => ErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(categoriesProvider),
            ),
          ),
          const SizedBox(height: 16),
          Text('Featured products', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          products.when(
            data: (list) => list.isEmpty
                ? const EmptyView(message: 'No products have been seeded yet.')
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: list.length,
                    itemBuilder: (context, i) => _ProductCard(product: list[i]),
                  ),
            loading: () => const LoadingView(label: 'Loading products…'),
            error: (e, _) => ErrorView(
              message: '$e',
              onRetry: () =>
                  ref.invalidate(productsProvider(const ProductFilter())),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.name, required this.onTap});
  final String name;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category_outlined, color: scheme.primary),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});
  final dynamic product;
  @override
  Widget build(BuildContext context) {
    final p = product;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/products/${p.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MarketplaceImage(
                url: p.imageUrls.isNotEmpty ? p.imageUrls.first : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${p.price.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium!
                        .copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.sellerId == null ? 'Official Store' : 'Reseller',
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
