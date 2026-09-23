import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlock/src/core/router/app_router.dart';
import 'package:openlock/src/core/theme.dart';

class OpenLockApp extends ConsumerWidget {
  const OpenLockApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Open Lock',
      theme: AppTheme.build(Brightness.light, accent: openlockAccent),
      darkTheme: AppTheme.build(Brightness.dark, accent: openlockAccent),
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
