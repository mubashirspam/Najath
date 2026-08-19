import 'package:najath_core/najath_core.dart';

import 'access_policy_dto.dart';
import 'app_user_dto.dart';

/// The whole shell, in one response.
///
/// `GET /api/v1/session` returns the user *and* their access policy together,
/// so a cold start is one round trip rather than two. On a halaqa's connection
/// that difference is felt.
class SessionDto {
  const SessionDto({
    required this.user,
    required this.policy,
    this.minSupportedAppVersion,
  });

  factory SessionDto.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    if (user is! Map<String, dynamic>) {
      throw const FormatException('session response carried no user');
    }

    final settings = json['settings'];

    return SessionDto(
      // The user object carries no role — roles are many-to-many and live
      // alongside it, so the active one is taken from the policy.
      user: AppUserDto.fromJson({
        ...user,
        'role': json['activeRole'],
        'phoneNumber': user['phone'],
      }),
      policy: AccessPolicyDto.fromJson({
        'roles': json['roles'],
        'activeRole': json['activeRole'],
        'permissions': json['permissions'],
        'screens': json['screens'],
        'scopes': json['scopes'],
        'version': json['policyVersion'],
      }),
      minSupportedAppVersion: settings is Map<String, dynamic>
          ? settings['minSupportedAppVersion']?.toString()
          : null,
    );
  }

  final AppUserDto user;
  final AccessPolicyDto policy;

  /// Below this, the app shows a blocking update screen. The only lever for
  /// retiring a broken sync client in the field.
  final String? minSupportedAppVersion;

  AccessPolicy toPolicy() => policy.toEntity(fetchedAt: DateTime.now());
}
