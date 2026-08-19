import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_auth/najath_auth.dart';
import 'package:najath_core/najath_core.dart';

/// Renders [child] only when the principal holds [permission].
///
/// The point is not security — the API re-checks everything — it is that a
/// teacher without `attendance:amend` should never see an Edit button they
/// cannot use. Defaults to rendering nothing, so forgetting the [fallback] is
/// the safe mistake.
class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    required this.permission,
    required this.child,
    this.fallback,
    super.key,
  });

  /// Convenience for the common `resource:action` pair.
  PermissionGate.of(
    String resource,
    String action, {
    required this.child,
    this.fallback,
    super.key,
  }) : permission = Permission(resource, action);

  final Permission permission;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(canProvider(permission));
    if (allowed) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Same idea, keyed on a screen rather than a permission.
///
/// Used by nav shells and by any in-app link into a screen the admin console
/// may have revoked, so a dead entry point never appears.
class ScreenGate extends ConsumerWidget {
  const ScreenGate({
    required this.screenId,
    required this.child,
    this.fallback,
    super.key,
  });

  final String screenId;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(canOpenProvider(screenId));
    if (allowed) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// What a user sees if they land on a screen their role cannot open — a deep
/// link, a push notification, or a permission revoked while the app was open.
class NoAccessView extends StatelessWidget {
  const NoAccessView({this.screenId, this.onBack, super.key});

  final String? screenId;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final section = screenId == null ? l10n.noAccessSectionFallback : screenLabel(l10n, screenId!);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.noAccessTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 56,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noAccessBody(section),
              style: context.text.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noAccessHint,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onBack != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onBack, child: Text(l10n.actionGoBack)),
            ],
          ],
        ),
      ),
    );
  }
}
