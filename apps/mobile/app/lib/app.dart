import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_design_system/najath_design_system.dart';

import 'app/router/app_routes.dart';
import 'flavors.dart';

class NajathApp extends ConsumerWidget {
  const NajathApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: F.title,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      // English and Malayalam from day one. The device locale decides; a
      // guardian who reads Malayalam should never have to find a setting.
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => _FlavorBanner(
        show: kDebugMode && F.appFlavor != Flavor.prod,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _FlavorBanner extends StatelessWidget {
  const _FlavorBanner({required this.child, required this.show});

  final Widget child;
  final bool show;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    return Banner(
      location: BannerLocation.topStart,
      message: F.name,
      color: Colors.green.withAlpha(150),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 1,
      ),
      textDirection: TextDirection.ltr,
      child: child,
    );
  }
}
