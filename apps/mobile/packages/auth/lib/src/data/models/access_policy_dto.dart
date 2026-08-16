import 'package:najath_core/najath_core.dart';

/// Wire shape of `GET /me/access`, matching `AccessPolicy` in
/// `@najath/contracts`.
class AccessPolicyDto {
  const AccessPolicyDto({
    required this.role,
    required this.permissions,
    required this.screens,
    required this.version,
  });

  factory AccessPolicyDto.fromJson(Map<String, dynamic> json) {
    return AccessPolicyDto(
      role: json['role']?.toString(),
      permissions: _stringList(json['permissions']),
      screens: _stringList(json['screens']),
      version: (json['version'] as num?)?.toInt() ?? 0,
    );
  }

  final String? role;
  final List<String> permissions;
  final List<String> screens;
  final int version;

  Map<String, dynamic> toJson() => {
    'role': role,
    'permissions': permissions,
    'screens': screens,
    'version': version,
  };

  AccessPolicy toEntity({DateTime? fetchedAt}) {
    return AccessPolicy(
      role: appRoleFromName(role),
      permissions: PermissionSet.fromWire(permissions),
      screens: screens.toSet(),
      version: version,
      fetchedAt: fetchedAt ?? DateTime.now(),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList();
  }
}
