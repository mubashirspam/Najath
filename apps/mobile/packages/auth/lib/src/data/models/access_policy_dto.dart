import 'package:najath_core/najath_core.dart';

/// Wire shape of `GET /me/access`, matching `AccessPolicy` in `@najath/contracts`.
class AccessPolicyDto {
  const AccessPolicyDto({
    required this.roles,
    required this.activeRole,
    required this.permissions,
    required this.screens,
    required this.scopes,
    required this.version,
  });

  factory AccessPolicyDto.fromJson(Map<String, dynamic> json) {
    final scopes = json['scopes'];
    return AccessPolicyDto(
      roles: _strings(json['roles']),
      activeRole: json['activeRole']?.toString(),
      permissions: _strings(json['permissions']),
      screens: _strings(json['screens']),
      scopes: scopes is Map<String, dynamic> ? scopes : const {},
      version: (json['version'] as num?)?.toInt() ?? 0,
    );
  }

  final List<String> roles;
  final String? activeRole;
  final List<String> permissions;
  final List<String> screens;
  final Map<String, dynamic> scopes;
  final int version;

  Map<String, dynamic> toJson() => {
    'roles': roles,
    'activeRole': activeRole,
    'permissions': permissions,
    'screens': screens,
    'scopes': scopes,
    'version': version,
  };

  AccessPolicy toEntity({DateTime? fetchedAt}) {
    return AccessPolicy(
      roles: roles.map(appRoleFromWire).toSet(),
      activeRole: appRoleFromWire(activeRole),
      permissions: PermissionSet.fromWire(permissions),
      screens: screens.toSet(),
      scopes: AccessScopes(
        departmentIds: _idSet('departmentIds'),
        batchIds: _idSet('batchIds'),
        classSectionIds: _idSet('classSectionIds'),
        hostelIds: _idSet('hostelIds'),
        wardIds: _idSet('wardIds'),
      ),
      version: version,
      fetchedAt: fetchedAt ?? DateTime.now(),
    );
  }

  Set<String> _idSet(String key) => _strings(scopes[key]).toSet();

  static List<String> _strings(Object? value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList();
  }
}
