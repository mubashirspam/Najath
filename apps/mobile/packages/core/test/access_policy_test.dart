import 'package:flutter_test/flutter_test.dart';
import 'package:najath_core/najath_core.dart';

void main() {
  group('PermissionSet', () {
    test('drops malformed wire entries rather than granting them', () {
      final set = PermissionSet.fromWire(const [
        'attendance:mark',
        'nonsense',
        'a:b:c',
        '',
        ':read',
      ]);

      expect(set.wires, {'attendance:mark'});
      expect(set.can('attendance', 'mark'), isTrue);
    });

    test('touches reports any action on a resource', () {
      final set = PermissionSet.fromWire(const ['hifz:record']);

      expect(set.touches('hifz'), isTrue);
      expect(set.touches('exam'), isFalse);
      // Must not match a resource that merely shares a prefix.
      expect(PermissionSet.fromWire(const ['exams:read']).touches('exam'), isFalse);
    });
  });

  group('AccessPolicy.canOpen', () {
    AccessPolicy policyWith({
      required Set<String> screens,
      required List<String> permissions,
    }) => AccessPolicy(
      role: AppRole.teacher,
      permissions: PermissionSet.fromWire(permissions),
      screens: screens,
      version: 3,
      fetchedAt: DateTime(2026, 8, 16),
    );

    test('opens a screen that is granted and backed by its permission', () {
      final policy = policyWith(
        screens: {ScreenId.attendance},
        permissions: ['attendance:read'],
      );

      expect(policy.canOpen(ScreenId.attendance), isTrue);
    });

    test('refuses a screen the matrix does not list', () {
      final policy = policyWith(screens: {}, permissions: ['attendance:read']);

      expect(policy.canOpen(ScreenId.attendance), isFalse);
    });

    test(
      'refuses a granted screen once its underlying permission is revoked',
      () {
        // The case the whole two-condition check exists for: an admin revokes
        // `attendance:read` but forgets to untick the screen.
        final policy = policyWith(
          screens: {ScreenId.attendance},
          permissions: ['hifz:read'],
        );

        expect(policy.canOpen(ScreenId.attendance), isFalse);
      },
    );

    test('refuses a screen id that is not in the registry', () {
      final policy = policyWith(
        screens: {'screen_removed_last_release'},
        permissions: ['attendance:read'],
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

  group('AccessPolicy.fallbackFor', () {
    test('grants a guardian the registry defaults and nothing more', () {
      final policy = AccessPolicy.fallbackFor(AppRole.guardian);

      expect(policy.canOpen(ScreenId.attendance), isTrue);
      // Marking is staff-only, and is not a nav destination a guardian gets.
      expect(policy.canOpen(ScreenId.attendanceMark), isFalse);
      expect(policy.canOpen(ScreenId.academics), isFalse);
      expect(policy.isFallback, isTrue);
    });

    test('admin defaults cover every registered screen', () {
      final policy = AccessPolicy.fallbackFor(AppRole.admin);

      for (final screen in ScreenRegistry.all) {
        expect(policy.canOpen(screen.id), isTrue, reason: screen.id);
      }
    });
  });

  group('AccessPolicy.isEquivalentTo', () {
    test('ignores fetchedAt so a no-op refetch does not rebuild the tree', () {
      final a = AccessPolicy(
        role: AppRole.staff,
        permissions: PermissionSet.fromWire(const ['attendance:read']),
        screens: {ScreenId.attendance},
        version: 7,
        fetchedAt: DateTime(2026, 8, 16),
      );
      final b = a.copyWith(fetchedAt: DateTime(2026, 8, 17));

      expect(a.isEquivalentTo(b), isTrue);
    });

    test('notices a version bump', () {
      final a = AccessPolicy(
        role: AppRole.staff,
        permissions: PermissionSet.fromWire(const ['attendance:read']),
        screens: {ScreenId.attendance},
        version: 7,
        fetchedAt: DateTime(2026, 8, 16),
      );

      expect(a.isEquivalentTo(a.copyWith(version: 8)), isFalse);
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
