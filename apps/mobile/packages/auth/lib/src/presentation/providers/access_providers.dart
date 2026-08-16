import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';

import '../notifiers/access_notifier.dart';

/// Whether the signed-in principal holds a permission.
///
/// A family so a widget rebuilds only when *its* answer changes — a teacher
/// gaining `exam:grade` should not repaint the attendance screen.
final Provider<bool> Function(Permission) canProvider = Provider.family<bool, Permission>((
  ref,
  permission,
) {
  return ref.watch(accessNotifierProvider).has(permission);
});

/// Whether a screen is reachable: listed for this role in the admin matrix
/// *and* still backed by the permission it needs.
final Provider<bool> Function(String) canOpenProvider = Provider.family<bool, String>((
  ref,
  screenId,
) {
  return ref.watch(accessNotifierProvider).canOpen(screenId);
});

/// Nav destinations this principal can actually open, in registry order.
///
/// The bottom bar and side rail are built from this, so revoking a screen in
/// the admin console removes the tab rather than leaving a dead one.
final visibleDestinationsProvider = Provider<List<ScreenDefinition>>((ref) {
  return ref.watch(accessNotifierProvider).visibleDestinations;
});

/// The principal's role, for the few places that genuinely branch on it rather
/// than on a permission — copy, empty states, which dashboard to show.
final currentRoleProvider = Provider<AppRole>((ref) {
  return ref.watch(accessNotifierProvider).role;
});

/// True while the app is running on registry defaults because no policy has
/// ever been fetched. Lets the UI say "showing defaults until we can reach the
/// server" instead of silently guessing.
final isPolicyFallbackProvider = Provider<bool>((ref) {
  return ref.watch(accessNotifierProvider).isFallback;
});
