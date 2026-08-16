import 'package:flutter/foundation.dart';
import 'package:najath_core/najath_core.dart';

/// The signed-in principal.
///
/// Staff sign in with email and password; guardians with a phone OTP — hence
/// both identifiers are nullable and [displayIdentifier] picks whichever the
/// account actually has.
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    this.email,
    this.phoneNumber,
    this.imageUrl,
  });

  final String id;
  final String name;
  final AppRole role;
  final String? email;
  final String? phoneNumber;
  final String? imageUrl;

  bool get isGuardian => role == AppRole.guardian;
  bool get isStaff => role == AppRole.staff || role == AppRole.admin;
  bool get isTeacher => role == AppRole.teacher;

  String get displayIdentifier => email ?? phoneNumber ?? id;

  /// First letter of each of the first two words, for the avatar fallback.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  AppUser copyWith({
    String? id,
    String? name,
    AppRole? role,
    String? email,
    String? phoneNumber,
    String? imageUrl,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  bool operator ==(Object other) => other is AppUser && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AppUser($id, ${role.name})';
}
