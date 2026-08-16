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
/// Matched on path shape rather than a second registry, which keeps this in
/// step with `RoutePath` automatically.
String? screenIdForLocation(String location) {
  final segments = Uri.parse(location).pathSegments;
  if (segments.isEmpty) return null;

  switch (segments.first) {
    // ── teacher ──
    case 'today':
      return ScreenId.today;
    case 'batches':
      if (segments.length >= 3 && segments[2] == 'attendance') {
        return ScreenId.batchAttendance;
      }
      if (segments.length >= 3 && segments[2] == 'hifz') return ScreenId.batchHifz;
      return ScreenId.batches;
    case 'classes':
      return ScreenId.marksEntry;
    case 'students':
      return ScreenId.studentDetail;
    case 'reports':
      return ScreenId.teacherReports;
    case 'leave':
      return ScreenId.leaveApprovals;

    // ── parent ──
    case 'wards':
      if (segments.length < 3) return ScreenId.wards;
      return switch (segments[2]) {
        'attendance' => ScreenId.wardAttendance,
        'hifz' when segments.length > 3 && segments[3] == 'doura' => ScreenId.wardDoura,
        'hifz' when segments.length > 3 => ScreenId.wardHifzHistory,
        'hifz' => ScreenId.wardHifz,
        'academics' => ScreenId.wardAcademics,
        'homework' => ScreenId.wardHomework,
        'results' => ScreenId.wardResults,
        'activities' => ScreenId.wardActivities,
        'leave' => ScreenId.wardLeave,
        'hostel' => ScreenId.wardHostel,
        'canteen' => ScreenId.wardCanteen,
        'reports' => ScreenId.wardReports,
        _ => ScreenId.wards,
      };
    case 'notices':
      return ScreenId.notices;

    // ── hostel ──
    case 'rollcall':
      return ScreenId.rollcall;
    case 'gate-pass':
      return ScreenId.gatePass;
    case 'occupancy':
      return ScreenId.occupancy;
    case 'visitors':
      return ScreenId.visitors;

    // Settings and the unsynced queue are not access-controlled: everyone who
    // can sign in may see their own preferences and their own pending work.
    default:
      return null;
  }
}

/// Where each shell opens.
String homeFor(AppShell shell) => switch (shell) {
  AppShell.teacher => RoutePath.today,
  AppShell.parent => RoutePath.wards,
  AppShell.hostel => RoutePath.rollcall,
};

/// The router's guard. Three jobs, in order.
String? handleRedirect(BuildContext context, GoRouterState state) {
  final container = ProviderScope.containerOf(context);
  final auth = container.read(authNotifierProvider);
  final path = state.uri.path;

  // 1. Bootstrap hold. While the stored session is being read back, park every
  //    route on the splash screen. Without this a cold start on a deep link
  //    evaluates the auth gate below before the token has been read, and
  //    bounces the user to login.
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

  final policy = container.read(accessNotifierProvider);

  if (path == RoutePath.login || path == RoutePath.splash) {
    return consumeInitialDeeplink() ?? homeFor(policy.shell);
  }

  // 3. Access gate. The server enforces this too — the point here is that a
  //    revoked screen reached by deep link or a stale push notification
  //    explains itself instead of rendering a page full of 403s.
  final screenId = screenIdForLocation(path);
  if (screenId != null && !policy.canOpen(screenId)) {
    return '${RoutePath.noAccess}?screen=$screenId';
  }

  return null;
}
