import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/screens.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final path = state.uri.path;
      if (session.isLoading) return path == '/splash' ? null : '/splash';
      final user = session.asData?.value;
      // These routes must remain reachable before a user has a session.
      // In particular, protecting /register redirected its own button back to
      // /login, making account creation impossible.
      const public = {
        '/home',
        '/catalog',
        '/login',
        '/register',
        '/terms',
        '/privacy',
      };
      final productPublic = path.startsWith('/products/');
      if (path == '/') return '/splash';
      if (path == '/splash') return null;
      if (user == null && !public.contains(path) && !productPublic) {
        final safe = path.startsWith('/') && !path.contains('://')
            ? Uri.encodeComponent(path)
            : null;
        return safe == null ? '/login' : '/login?from=$safe';
      }
      if (user != null && (path == '/login' || path == '/register')) {
        return '/home';
      }
      if (path.startsWith('/reseller/')) {
        if (path == '/reseller/application') return null;
        if (!user!.isApprovedReseller) return '/reseller/application';
      }
      if (path.startsWith('/upload') && user == null) return '/login';
      if (path.startsWith('/admin') && !user!.isAdmin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/splash'),
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: '/login',
        builder: (_, state) =>
            LoginScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/terms',
        builder: (_, _) =>
            const PolicyScreen(title: 'P1 Terms of Use', body: termsText),
      ),
      GoRoute(
        path: '/privacy',
        builder: (_, _) =>
            const PolicyScreen(title: 'P1 Privacy Notice', body: privacyText),
      ),
      GoRoute(
        path: '/products/:id',
        builder: (_, state) =>
            ProductDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/addresses', builder: (_, _) => const AddressesScreen()),
      GoRoute(
        path: '/addresses/new',
        builder: (_, _) => const AddressFormScreen(),
      ),
      GoRoute(path: '/checkout', builder: (_, _) => const CheckoutScreen()),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) =>
            OrderDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/upload/:id',
        builder: (_, state) => ImageUploadScreen(
          productId: int.parse(state.pathParameters['id']!),
          returnPath: state.uri.queryParameters['return'] ?? '/home',
        ),
      ),
      GoRoute(
        path: '/reseller/application',
        builder: (_, _) => const ResellerApplicationScreen(),
      ),
      GoRoute(
        path: '/reseller/center',
        builder: (_, _) => const ResellerCenterScreen(),
      ),
      GoRoute(
        path: '/reseller/products',
        builder: (_, _) => const ManagedProductsScreen(official: false),
      ),
      GoRoute(
        path: '/reseller/products/:id/edit',
        builder: (_, state) => ProductFormScreen(
          official: false,
          productId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/reseller/products/new',
        builder: (_, _) => const ProductFormScreen(official: false),
      ),
      GoRoute(
        path: '/reseller/orders',
        builder: (_, _) => const ResellerOrdersScreen(),
      ),
      GoRoute(
        path: '/reseller/orders/:id',
        builder: (_, state) =>
            ResellerOrderScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/admin', builder: (_, _) => const AdminScreen()),
      GoRoute(
        path: '/admin/reseller-applications',
        builder: (_, _) => const AdminApplicationsScreen(),
      ),
      GoRoute(
        path: '/admin/products/new',
        builder: (_, _) => const ProductFormScreen(official: true),
      ),
      GoRoute(
        path: '/admin/products',
        builder: (_, _) => const ManagedProductsScreen(official: true),
      ),
      GoRoute(
        path: '/admin/products/:id/edit',
        builder: (_, state) => ProductFormScreen(
          official: true,
          productId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/admin/orders',
        builder: (_, _) => const AdminOrdersScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/catalog', builder: (_, _) => const CatalogScreen()),
          GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
          GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen()),
          GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
        ],
      ),
    ],
  );
});
