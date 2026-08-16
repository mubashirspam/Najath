import 'package:flutter_test/flutter_test.dart';
import 'package:najath_core/najath_core.dart';

void main() {
  group('PermissionSet', () {
    test('drops malformed wire entries rather than granting them', () {
      final set = PermissionSet.fromWire(const [
        'attendance:create',
        'nonsense',
        'a:b:c',
        '',
        ':read',
      ]);

      expect(set.wires, {'attendance:create'});
      expect(set.can('attendance', 'create'), isTrue);
    });

    test('touches reports any action on a resource', () {
      final set = PermissionSet.fromWire(const ['hifzLog:create']);

      expect(set.touches('hifzLog'), isTrue);
      expect(set.touches('exam'), isFalse);
      // Must not match a resource that merely shares a prefix.
      expect(PermissionSet.fromWire(const ['hifzLogs:read']).touches('hifzLog'), isFalse);
    });
  });

  group('AccessPolicy.canOpen', () {
    AccessPolicy policyWith({
      required Set<String> screens,
      required List<String> permissions,
      AppRole role = AppRole.teacher,
    }) => AccessPolicy(
      roles: {role},
      activeRole: role,
      permissions: PermissionSet.fromWire(permissions),
      screens: screens,
      scopes: const AccessScopes.empty(),
      version: 3,
      fetchedAt: DateTime(2026, 8, 16),
    );

    test('opens a screen that is granted and backed by its permission', () {
      final policy = policyWith(
        screens: {ScreenId.batchHifz},
        permissions: ['hifzLog:create'],
      );

      expect(policy.canOpen(ScreenId.batchHifz), isTrue);
    });

    test('refuses a screen the matrix does not list', () {
      final policy = policyWith(screens: {}, permissions: ['hifzLog:create']);

      expect(policy.canOpen(ScreenId.batchHifz), isFalse);
    });

    test(
      'refuses a granted screen once its underlying permission is revoked',
      () {
        // The case the two-condition check exists for: an admin revokes
        // `hifzLog:create` but forgets to untick the screen.
        final policy = policyWith(
          screens: {ScreenId.batchHifz},
          permissions: ['attendance:read'],
        );

        expect(policy.canOpen(ScreenId.batchHifz), isFalse);
      },
    );

    test('refuses a screen id that is not in the registry', () {
      final policy = policyWith(
        screens: {'screen_removed_last_release'},
        permissions: ['hifzLog:create'],
      );

      expect(policy.canOpen('screen_removed_last_release'), isFalse);
    });

    test('deny-all opens nothing', () {
      const policy = AccessPolicy.denyAll();

      for (final screen in ScreenRegistry.all) {
        expect(policy.canOpen(screen.id), isFalse, reason: screen.id);
      }
      expect(policy.isFallback, isTrue);
    });
  });

  group('shells', () {
    test('each role resolves to exactly one shell', () {
      expect(shellForRole(AppRole.teacher), AppShell.teacher);
      expect(shellForRole(AppRole.deptHead), AppShell.teacher);
      expect(shellForRole(AppRole.parent), AppShell.parent);
      expect(shellForRole(AppRole.hostelWarden), AppShell.hostel);
    });

    test('visible destinations are scoped to the active shell', () {
      final policy = AccessPolicy.fallbackFor(AppRole.parent);

      expect(policy.shell, AppShell.parent);
      for (final destination in policy.visibleDestinations) {
        expect(destination.shell, AppShell.parent, reason: destination.id);
      }
      // A parent never sees a teacher tab, even by accident.
      expect(
        policy.visibleDestinations.map((d) => d.id),
        isNot(contains(ScreenId.batches)),
      );
    });

    test('switching the active role switches the shell', () {
      // A teacher who is also a parent of a student in the same college.
      final policy = AccessPolicy(
        roles: const {AppRole.teacher, AppRole.parent},
        activeRole: AppRole.teacher,
        permissions: PermissionSet.fromWire(const [
          'timetable:read',
          'student:read',
        ]),
        screens: const {ScreenId.today, ScreenId.wards},
        scopes: const AccessScopes(wardIds: {'student-9'}),
        version: 1,
        fetchedAt: DateTime(2026, 8, 16),
      );

      expect(policy.shell, AppShell.teacher);
      expect(policy.hasMultipleRoles, isTrue);
      expect(policy.copyWith(activeRole: AppRole.parent).shell, AppShell.parent);
    });
  });

  group('AccessPolicy.fallbackFor', () {
    test('grants a parent the registry defaults and nothing more', () {
      final policy = AccessPolicy.fallbackFor(AppRole.parent);

      expect(policy.canOpen(ScreenId.wards), isTrue);
      expect(policy.canOpen(ScreenId.wardHifz), isTrue);
      // Teacher screens are not a parent's, whatever the shell.
      expect(policy.canOpen(ScreenId.batchHifz), isFalse);
      expect(policy.canOpen(ScreenId.rollcall), isFalse);
      expect(policy.isFallback, isTrue);
    });

    test('a canteen manager gets no mobile screens at all', () {
      // Canteen is a console-only module; the registry has no canteen shell.
      final policy = AccessPolicy.fallbackFor(AppRole.canteenManager);

      expect(policy.visibleDestinations, isEmpty);
    });
  });

  group('AccessScopes', () {
    test("ward scope contains only this guardian's children", () {
      const scopes = AccessScopes(wardIds: {'student-1'});

      expect(scopes.contains(ScopeType.ward, 'student-1'), isTrue);
      // The failure the whole design exists to prevent.
      expect(scopes.contains(ScopeType.ward, 'student-2'), isFalse);
    });

    test('assigned scope covers batches and class sections', () {
      const scopes = AccessScopes(
        batchIds: {'batch-1'},
        classSectionIds: {'class-1'},
      );

      expect(scopes.contains(ScopeType.assigned, 'batch-1'), isTrue);
      expect(scopes.contains(ScopeType.assigned, 'class-1'), isTrue);
      expect(scopes.contains(ScopeType.assigned, 'batch-9'), isFalse);
    });

    test('global contains everything, none contains nothing', () {
      const scopes = AccessScopes.empty();

      expect(scopes.contains(ScopeType.global, 'anything'), isTrue);
      expect(scopes.contains(ScopeType.none, 'anything'), isFalse);
    });
  });

  group('AccessPolicy.isEquivalentTo', () {
    final base = AccessPolicy(
      roles: const {AppRole.teacher},
      activeRole: AppRole.teacher,
      permissions: PermissionSet.fromWire(const ['attendance:read']),
      screens: const {ScreenId.today},
      scopes: const AccessScopes.empty(),
      version: 7,
      fetchedAt: DateTime(2026, 8, 16),
    );

    test('ignores fetchedAt so a no-op refetch does not rebuild the tree', () {
      expect(base.isEquivalentTo(base.copyWith(fetchedAt: DateTime(2026, 8, 17))), isTrue);
    });

    test('notices a version bump and a role switch', () {
      expect(base.isEquivalentTo(base.copyWith(version: 8)), isFalse);
      expect(base.isEquivalentTo(base.copyWith(activeRole: AppRole.parent)), isFalse);
    });
  });

  group('EnvConfig', () {
    test('derives the Better Auth root one level above the v1 API', () {
      const config = EnvConfig(
        env: Environment.dev,
        apiBaseUrl: 'http://10.0.2.2:3000/api/v1',
        enableLogging: true,
      );

      expect(config.authBaseUrl, 'http://10.0.2.2:3000/api');
    });

    test('tolerates a trailing slash', () {
      const config = EnvConfig(
        env: Environment.prod,
        apiBaseUrl: 'https://najath.app/api/v1/',
        enableLogging: false,
      );

      expect(config.authBaseUrl, 'https://najath.app/api');
    });
  });
}
