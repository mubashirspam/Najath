import 'permission.dart';
import 'screen_registry.dart';

/// The concrete ids each scope reaches.
///
/// A permission alone is not actionable: `attendance:create` does not say
/// which batches. The server resolves these once per session — a teacher's
/// batches from staff assignments, a guardian's wards from student_guardians —
/// and the app filters against them.
class AccessScopes {
  const AccessScopes({
    this.departmentIds = const {},
    this.batchIds = const {},
    this.classSectionIds = const {},
    this.hostelIds = const {},
    this.wardIds = const {},
  });

  const AccessScopes.empty()
    : departmentIds = const {},
      batchIds = const {},
      classSectionIds = const {},
      hostelIds = const {},
      wardIds = const {};

  final Set<String> departmentIds;
  final Set<String> batchIds;
  final Set<String> classSectionIds;
  final Set<String> hostelIds;

  /// Students reachable through guardianship. The only path a non-staff account
  /// has to a student record.
  final Set<String> wardIds;

  bool get hasWards => wardIds.isNotEmpty;

  /// Whether a concrete id is inside a scope the principal holds.
  bool contains(ScopeType scope, String id) => switch (scope) {
    ScopeType.global => true,
    ScopeType.department => departmentIds.contains(id),
    ScopeType.assigned => batchIds.contains(id) || classSectionIds.contains(id),
    ScopeType.hostel => hostelIds.contains(id),
    ScopeType.ward => wardIds.contains(id),
    ScopeType.self => false,
    ScopeType.none => false,
  };
}

/// What the signed-in principal may do and see.
///
/// Resolved server-side from the role matrix the admin console edits, then
/// cached on device so the app stays correctly restricted offline. The server
/// enforces the same rules — this exists so the UI does not offer affordances
/// that would 403.
class AccessPolicy {
  const AccessPolicy({
    required this.roles,
    required this.activeRole,
    required this.permissions,
    required this.screens,
    required this.scopes,
    required this.version,
    required this.fetchedAt,
  });

  /// Before any fetch has succeeded: nothing is visible. Deny by default, so a
  /// failed fetch can never open a screen.
  const AccessPolicy.denyAll()
    : roles = const {},
      activeRole = AppRole.parent,
      permissions = const PermissionSet.empty(),
      screens = const {},
      scopes = const AccessScopes.empty(),
      version = 0,
      fetchedAt = null;

  /// The registry's built-in defaults for [role].
  ///
  /// Used only when the app knows the role — from a restored session — but has
  /// never reached `/me/access`. Every screen it opens still calls an API that
  /// re-checks server-side, so being generous here costs nothing but a
  /// friendlier empty state.
  factory AccessPolicy.fallbackFor(AppRole role) {
    final screens = ScreenRegistry.defaultScreensFor(role);
    return AccessPolicy(
      roles: {role},
      activeRole: role,
      permissions: PermissionSet.fromWire(
        ScreenRegistry.all.where((s) => screens.contains(s.id)).map((s) => s.requires.wire),
      ),
      screens: screens,
      scopes: const AccessScopes.empty(),
      version: 0,
      fetchedAt: null,
    );
  }

  /// Every role the principal holds. A DEPT_HEAD is usually also a TEACHER, and
  /// a TEACHER may be a PARENT of a student in the same college.
  final Set<AppRole> roles;

  /// The role the shell is currently showing. Switching rebuilds the router
  /// without re-authenticating.
  final AppRole activeRole;

  final PermissionSet permissions;
  final Set<String> screens;
  final AccessScopes scopes;

  /// Bumped by the server whenever an admin edits the matrix.
  final int version;

  /// Null means this is a fallback, not a server answer.
  final DateTime? fetchedAt;

  bool get isFallback => fetchedAt == null;

  bool get hasMultipleRoles => roles.length > 1;

  /// The shell the active role resolves to.
  AppShell get shell => shellForRole(activeRole);

  bool can(String resource, String action) => permissions.can(resource, action);

  bool has(Permission permission) => permissions.has(permission);

  /// Whether a screen is reachable.
  ///
  /// Both conditions must hold: the admin matrix lists the screen, **and** the
  /// principal still carries the permission it needs. The second check means
  /// revoking a permission closes every screen that depends on it without
  /// anyone having to update the matrix too.
  bool canOpen(String screenId) {
    if (!screens.contains(screenId)) return false;
    final definition = ScreenRegistry.byId(screenId);
    if (definition == null) return false;
    return permissions.has(definition.requires);
  }

  /// Nav destinations for the active shell, in registry order.
  List<ScreenDefinition> get visibleDestinations =>
      ScreenRegistry.navDestinations(shell).where((s) => canOpen(s.id)).toList();

  /// True when [other] would change anything the UI renders.
  bool isEquivalentTo(AccessPolicy other) =>
      other.activeRole == activeRole &&
      other.version == version &&
      other.permissions == permissions &&
      other.roles.length == roles.length &&
      other.roles.containsAll(roles) &&
      other.screens.length == screens.length &&
      other.screens.containsAll(screens);

  AccessPolicy copyWith({
    Set<AppRole>? roles,
    AppRole? activeRole,
    PermissionSet? permissions,
    Set<String>? screens,
    AccessScopes? scopes,
    int? version,
    DateTime? fetchedAt,
  }) {
    return AccessPolicy(
      roles: roles ?? this.roles,
      activeRole: activeRole ?? this.activeRole,
      permissions: permissions ?? this.permissions,
      screens: screens ?? this.screens,
      scopes: scopes ?? this.scopes,
      version: version ?? this.version,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  @override
  String toString() => 'AccessPolicy(${activeRole.wire}, ${screens.length} screens, v$version)';
}
