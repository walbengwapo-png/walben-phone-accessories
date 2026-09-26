import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Single adaptive bottom-navigation shell for the top-level customer routes.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  static const _tabs = [
    (
      icon: Icons.home_outlined,
      selected: Icons.home,
      label: 'Home',
      path: '/home',
    ),
    (
      icon: Icons.grid_view_outlined,
      selected: Icons.grid_view,
      label: 'Browse',
      path: '/catalog',
    ),
    (
      icon: Icons.shopping_cart_outlined,
      selected: Icons.shopping_cart,
      label: 'Cart',
      path: '/cart',
    ),
    (
      icon: Icons.receipt_long_outlined,
      selected: Icons.receipt_long,
      label: 'Orders',
      path: '/orders',
    ),
    (
      icon: Icons.person_outline,
      selected: Icons.person,
      label: 'Account',
      path: '/account',
    ),
  ];

  int _selectedIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _tabs.length; i++) {
      if (path == _tabs[i].path) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected < 0 ? 0 : selected,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selected),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
