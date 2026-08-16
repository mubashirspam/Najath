import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:najath_attendance/najath_attendance.dart';
import 'package:najath_auth/najath_auth.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_design_system/najath_design_system.dart';

import '../../features/dashboard/home_shell.dart';
import '../../features/dashboard/module_placeholder.dart';
import '../../features/dashboard/unsynced_screen.dart';
import '../../features/login/login_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import 'redirect.dart';
import 'route_path.dart';

/// Re-runs the router's redirect when the session or the access policy changes.
///
/// Both matter: signing out must eject the user, switching role must rebuild
/// the shell, and an admin revoking a screen mid-session must close it rather
/// than wait for the next navigation.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref
      ..listen(authNotifierProvider, (_, _) => notifyListeners())
      ..listen(accessNotifierProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}

/// Every screen wraps in the shell that owns it, so the nav bar and the banners
/// are declared once rather than per screen.
GoRoute _shellRoute(String path, String screenId, WidgetBuilder body) {
  return GoRoute(
    path: path,
    builder: (context, state) => HomeShell(
      screenId: screenId,
      child: Builder(builder: body),
    ),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: RoutePath.splash,
    refreshListenable: refresh,
    redirect: handleRedirect,
    errorBuilder: (context, state) =>
        ModulePlaceholder(title: 'Page not found', message: state.uri.path),
    routes: [
      GoRoute(path: RoutePath.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: RoutePath.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: RoutePath.noAccess,
        builder: (context, state) => NoAccessView(
          screenId: state.uri.queryParameters['screen'],
          onBack: () => context.go(
            homeFor(ref.read(accessNotifierProvider).shell),
          ),
        ),
      ),
      GoRoute(path: RoutePath.settings, builder: (_, _) => const SettingsScreen()),
      GoRoute(path: RoutePath.unsynced, builder: (_, _) => const UnsyncedScreen()),

      // ── Teacher shell ───────────────────────────────────────────────────────
      _shellRoute(
        RoutePath.today,
        ScreenId.today,
        (_) => const ModulePlaceholder(title: 'Today', message: 'M05-APP-01'),
      ),
      GoRoute(
        path: RoutePath.batches,
        builder: (_, _) => const HomeShell(
          screenId: ScreenId.batches,
          child: ModulePlaceholder(title: 'Batches', message: 'M03-APP-01'),
        ),
        routes: [
          GoRoute(
            path: ':batchId/attendance',
            builder: (context, state) => AttendanceRosterScreen(
              batchId: state.pathParameters['batchId'] ?? '',
              date: state.uri.queryParameters['date'] ?? IstDate.today(),
              title: state.uri.queryParameters['title'] ?? 'Roster',
            ),
          ),
          GoRoute(
            path: ':batchId/hifz',
            builder: (_, _) => const ModulePlaceholder(
              title: 'Hifz quick log',
              message: 'M04-APP-01…11 — the most important screen in the product',
            ),
          ),
        ],
      ),
      _shellRoute(
        RoutePath.teacherReports,
        ScreenId.teacherReports,
        (_) => const ModulePlaceholder(title: 'Reports', message: 'M07'),
      ),
      GoRoute(
        path: RoutePath.leaveApprovals,
        builder: (_, _) => const ModulePlaceholder(title: 'Leave approvals', message: 'M09-APP-04'),
      ),
      GoRoute(
        path: '/students/:studentId',
        builder: (_, _) => const ModulePlaceholder(title: 'Student', message: 'M02-APP-01'),
      ),
      GoRoute(
        path: '/classes/:classSectionId/marks/:examId',
        builder: (_, _) => const ModulePlaceholder(title: 'Marks entry', message: 'M06-APP-01'),
      ),

      // ── Parent shell ────────────────────────────────────────────────────────
      _shellRoute(
        RoutePath.wards,
        ScreenId.wards,
        (_) => const ModulePlaceholder(title: 'Wards', message: 'M02-APP-03'),
      ),
      GoRoute(
        path: '/wards/:studentId',
        builder: (_, _) => const ModulePlaceholder(title: 'Ward', message: 'M02-APP-04'),
        routes: [
          for (final segment in const [
            'attendance',
            'hifz',
            'academics',
            'homework',
            'results',
            'activities',
            'leave',
            'hostel',
            'canteen',
            'reports',
          ])
            GoRoute(
              path: segment,
              builder: (_, _) => ModulePlaceholder(title: segment),
            ),
        ],
      ),
      _shellRoute(
        RoutePath.notices,
        ScreenId.notices,
        (_) => const ModulePlaceholder(title: 'Notices', message: 'M12-APP-03'),
      ),

      // ── Hostel shell ────────────────────────────────────────────────────────
      _shellRoute(
        RoutePath.rollcall,
        ScreenId.rollcall,
        (_) => const ModulePlaceholder(title: 'Roll call', message: 'M10-APP-01'),
      ),
      _shellRoute(
        RoutePath.gatePass,
        ScreenId.gatePass,
        (_) => const ModulePlaceholder(title: 'Gate pass', message: 'M10-APP-03'),
      ),
      _shellRoute(
        RoutePath.occupancy,
        ScreenId.occupancy,
        (_) => const ModulePlaceholder(title: 'Occupancy', message: 'M10-ADM-01'),
      ),
      GoRoute(
        path: RoutePath.visitors,
        builder: (_, _) => const ModulePlaceholder(title: 'Visitors', message: 'M10-APP-04'),
      ),
    ],
  );
});
