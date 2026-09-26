import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class MarketplaceApp extends ConsumerWidget {
  const MarketplaceApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Phone Accessories Marketplace',
    theme: marketplaceTheme(Brightness.light),
    darkTheme: marketplaceTheme(Brightness.dark),
    themeMode: ThemeMode.system,
    routerConfig: ref.watch(routerProvider),
    debugShowCheckedModeBanner: false,
  );
}
