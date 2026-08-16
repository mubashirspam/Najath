import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:najath_auth/najath_auth.dart';
import 'package:najath_core/najath_core.dart';

import 'route_path.dart';

String? _initialDeeplink;

/// Returns the URL the user originally asked for and clears it, so it is
/// replayed exactly once after sign-in.
String? consumeInitialDeeplink() {
  final link = _initialDeeplink;
  _initialDeeplink = null;
  if (link == null) return null;

  final path = Uri.parse(link).path;
  // Never restore into the screens that exist to get you somewhere else.
  if (path == RoutePath.splash || path == RoutePath.login || path == RoutePath.noAccess) {
    return null;
  }
  return link;
}

/// Maps a URL back to the screen id it belongs to, so the guard can ask the
/// access policy about it.
///
/// Matched on the first path segment under `/home`, which keeps this in step
/// with `RoutePath` without a second registry to maintain.
String? screenIdForLocation(String location) {
  final segments = Uri.parse(location).pathSegments;
  if (segments.isEmpty) return null;
  if (segments.first != 'home') return null;
  if (segments.length == 1) return ScreenId.dashboard;

  return switch (segments[1]) {
    'attendance' => ScreenId.attendance,
    'hifz' => ScreenId.hifz,
    'academics' => ScreenId.academics,
    'exams' => ScreenId.exams,
    'progress' => ScreenId.progress,
    'leave' => ScreenId.leave,
    'hostel' => ScreenId.hostel,
    'canteen' => ScreenId.canteen,
    'activities' => ScreenId.activities,
    'announcements' => ScreenId.announcements,
    'profile' => ScreenId.profile,
    // Settings and the unsynced queue are not access-controlled: everyone who
    // can sign in can see their own preferences and their own pending work.
    _ => null,
  };
}

/// The router's guard. Three jobs, in order.
String? handleRedirect(BuildContext context, GoRouterState state) {
  final container = ProviderScope.containerOf(context);
  final auth = container.read(authNotifierProvider);
  final path = state.uri.path;

  // 1. Bootstrap hold. While the stored session is being read back, park every
  //    route on the splash screen. Without this a cold start on a deep link
  //    evaluates the auth gate below before the token has been read and bounces
  //    the user to login.
  if (!auth.initialized) {
    if (path == RoutePath.splash) return null;
    _initialDeeplink ??= state.uri.toString();
    return RoutePath.splash;
  }

  // 2. Auth gate.
  if (!auth.isAuthenticated) {
    if (path == RoutePath.login) return null;
    _initialDeeplink ??= state.uri.toString();
    return RoutePath.login;
  }

  if (path == RoutePath.login || path == RoutePath.splash) {
    return consumeInitialDeeplink() ?? RoutePath.home();
  }

  // 3. Access gate. The server enforces this too — the point here is that a
  //    revoked screen reached by deep link or by a stale push notification
  //    explains itself instead of rendering an empty page full of 403s.
  final screenId = screenIdForLocation(path);
  if (screenId != null) {
    final policy = container.read(accessNotifierProvider);
    if (!policy.canOpen(screenId)) {
      return '${RoutePath.noAccess}?screen=$screenId';
    }
  }

  return null;
}
