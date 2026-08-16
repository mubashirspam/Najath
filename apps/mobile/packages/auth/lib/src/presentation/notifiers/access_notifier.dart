import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_network/najath_network.dart';

import '../../data/repositories/access_repository_impl.dart';

/// Holds the effective access policy for the signed-in principal.
///
/// A `Notifier`, not an `AsyncNotifier`: the router's redirect guard reads it
/// synchronously on every navigation, and there is always *a* policy — deny-all
/// before anything has loaded — so there is no meaningful loading state to
/// render. Freshness is tracked by [AccessPolicy.isFallback] instead.
class AccessNotifier extends Notifier<AccessPolicy> {
  bool _refreshing = false;

  @override
  AccessPolicy build() => const AccessPolicy.denyAll();

  /// Loads the cached policy, then refreshes from the server when online.
  ///
  /// [role] comes from the restored session and is used only to pick a sensible
  /// fallback if nothing has ever been cached — a guardian on their first
  /// offline launch sees the guardian screens rather than an empty app.
  Future<void> load(AppRole role) async {
    final repository = ref.read(accessRepositoryProvider);
    final cached = await repository.cached();

    state = cached ?? AccessPolicy.fallbackFor(role);

    final online = ref.read(isOnlineProvider);
    if (!online) return;
    if (cached != null && !await repository.isStale()) return;

    await refresh();
  }

  /// Refetches from the server.
  ///
  /// Called on sign-in, on a stale cache, and whenever the API answers 403 —
  /// which means an admin changed the matrix since the last fetch.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final result = await ref.read(accessRepositoryProvider).fetch();
      final fresh = result.valueOrNull;
      // A failed refresh keeps whatever is cached. Never fall back to deny-all
      // on a network blip — that would empty the nav bar mid-lesson.
      if (fresh == null) return;
      // Skip the emission when nothing the UI renders has changed, so a
      // periodic refresh does not rebuild every guarded widget in the tree.
      if (state.isEquivalentTo(fresh)) return;
      state = fresh;
    } finally {
      _refreshing = false;
    }
  }

  /// Switches which role the shell is showing.
  ///
  /// Not a re-authentication: the session already carries every role. This
  /// changes which one the router and nav resolve against, which is what a
  /// teacher-who-is-also-a-parent does daily.
  void switchRole(AppRole role) {
    if (!state.roles.contains(role) || role == state.activeRole) return;
    state = state.copyWith(activeRole: role);
  }

  /// Drops back to deny-all. Called on sign-out, before the next principal's
  /// policy is loaded.
  Future<void> clear() async {
    await ref.read(accessRepositoryProvider).clear();
    state = const AccessPolicy.denyAll();
  }
}

final accessNotifierProvider = NotifierProvider<AccessNotifier, AccessPolicy>(
  AccessNotifier.new,
);
