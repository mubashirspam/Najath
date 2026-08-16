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
/// Both matter: signing out must eject the user, and an admin revoking a screen
/// mid-session must close it rather than wait for the next navigation.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref
      ..listen(authNotifierProvider, (_, _) => notifyListeners())
      ..listen(accessNotifierProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
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
      GoRoute(
        path: RoutePath.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePath.login,
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePath.noAccess,
        builder: (context, state) => NoAccessView(
          screenId: state.uri.queryParameters['screen'],
          onBack: () => context.go(RoutePath.home()),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, state) => HomeShell(
          tabIndex: int.tryParse(state.uri.queryParameters['t'] ?? '0') ?? 0,
        ),
        routes: [
          GoRoute(
            path: 'attendance',
            builder: (context, _) => AttendanceSessionsScreen(
              onOpenSession: (session) => context.push(
                RoutePath.attendanceRoster(
                  sessionId: session.id,
                  title: session.className,
                  isFinalised: session.isFinalised,
                ),
              ),
            ),
            routes: [
              GoRoute(
                path: 'roster',
                builder: (_, state) {
                  final params = state.uri.queryParameters;
                  return AttendanceRosterScreen(
                    sessionId: params['id'] ?? '',
                    title: params['title'] ?? 'Roster',
                    isFinalised: params['final'] == 'true',
                  );
                },
              ),
            ],
          ),
          // Modules whose feature packages are still stubs. Each is already
          // access-gated by the redirect, so wiring the real screen later is a
          // one-line swap.
          ..._placeholders,
          GoRoute(
            path: 'settings',
            builder: (_, _) => const SettingsScreen(),
          ),
          GoRoute(
            path: 'unsynced',
            builder: (_, _) => const UnsyncedScreen(),
          ),
        ],
      ),
    ],
  );
});

/// One route per not-yet-built module, named from the shared screen registry so
/// nothing can be forgotten when a screen is added on the server side.
final List<GoRoute> _placeholders = [
  for (final screen in ScreenRegistry.all)
    if (screen.isNavDestination &&
        screen.id != ScreenId.dashboard &&
        screen.id != ScreenId.attendance)
      GoRoute(
        path: _pathSegmentFor(screen.id),
        builder: (_, _) => ModulePlaceholder(title: screen.label),
      ),
];

String _pathSegmentFor(String screenId) => screenId.replaceAll('_', '-');
