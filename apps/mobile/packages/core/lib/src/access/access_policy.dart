import 'permission.dart';
import 'screen_registry.dart';

/// What the signed-in principal is allowed to do and see.
///
/// Resolved by the server from the role matrix the admin console edits, then
/// cached on device so the app is still correctly restricted offline. The
/// server enforces the same rules — this exists so the UI does not offer
/// affordances that would 403, not as the security boundary.
class AccessPolicy {
  const AccessPolicy({
    required this.role,
    required this.permissions,
    required this.screens,
    required this.version,
    required this.fetchedAt,
  });

  /// The policy used before any fetch has ever succeeded: nothing is visible
  /// beyond what [AccessPolicy.fallbackFor] explicitly grants. Deny-by-default
  /// so a failed fetch cannot open a screen.
  const AccessPolicy.denyAll()
    : role = AppRole.guardian,
      permissions = const PermissionSet.empty(),
      screens = const {},
      version = 0,
      fetchedAt = null;

  /// The registry's built-in defaults for [role].
  ///
  /// Used only when the app knows the role — from a live session — but has
  /// never reached `/me/access`, e.g. first launch on a plane. Any screen it
  /// opens still calls an API that re-checks server-side, so being generous
  /// here costs nothing but a friendlier empty state.
  factory AccessPolicy.fallbackFor(AppRole role) {
    final screens = ScreenRegistry.defaultScreensFor(role);
    return AccessPolicy(
      role: role,
      permissions: PermissionSet.fromWire(
        ScreenRegistry.all.where((s) => screens.contains(s.id)).map((s) => s.requires.wire),
      ),
      screens: screens,
      version: 0,
      fetchedAt: null,
    );
  }

  final AppRole role;
  final PermissionSet permissions;
  final Set<String> screens;

  /// Bumped by the server whenever an admin edits the matrix.
  final int version;

  /// When this policy was last fetched. Null means it is a fallback, not a
  /// server answer.
  final DateTime? fetchedAt;

  bool get isFallback => fetchedAt == null;

  bool get isAdmin => role == AppRole.admin;

  /// Whether the principal may perform `resource:action`.
  bool can(String resource, String action) => permissions.can(resource, action);

  bool has(Permission permission) => permissions.has(permission);

  /// Whether a screen is reachable.
  ///
  /// Both conditions must hold: the admin matrix lists the screen for this
  /// role, **and** the role still carries the permission the screen needs. The
  /// second check means revoking a permission closes every screen that depends
  /// on it without anyone having to remember to update the matrix too.
  bool canOpen(String screenId) {
    if (!screens.contains(screenId)) return false;
    final definition = ScreenRegistry.byId(screenId);
    if (definition == null) return false;
    return permissions.has(definition.requires);
  }

  /// Nav destinations this principal can actually open, in registry order.
  List<ScreenDefinition> get visibleDestinations =>
      ScreenRegistry.navDestinations.where((s) => canOpen(s.id)).toList();

  /// True when [other] would change anything the UI renders. Lets the notifier
  /// skip a state emission on an identical refetch.
  bool isEquivalentTo(AccessPolicy other) =>
      other.role == role &&
      other.version == version &&
      other.permissions == permissions &&
      other.screens.length == screens.length &&
      other.screens.containsAll(screens);

  AccessPolicy copyWith({
    AppRole? role,
    PermissionSet? permissions,
    Set<String>? screens,
    int? version,
    DateTime? fetchedAt,
  }) {
    return AccessPolicy(
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      screens: screens ?? this.screens,
      version: version ?? this.version,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  @override
  String toString() => 'AccessPolicy(role: ${role.name}, screens: ${screens.length}, v$version)';
}
