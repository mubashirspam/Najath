import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_auth/najath_auth.dart';
import 'package:najath_core/najath_core.dart';

/// Held on screen by the router's redirect while the stored session is read
/// back, then replaced automatically once `initialized` flips.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched so the redirect re-runs the moment bootstrap finishes; nothing
    // here has to navigate by hand.
    ref.watch(authNotifierProvider);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.appName,
              style: context.text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.appTagline,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
