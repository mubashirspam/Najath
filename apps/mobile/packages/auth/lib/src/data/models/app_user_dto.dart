import 'package:najath_core/najath_core.dart';

import '../../domain/entities/app_user.dart';

/// Wire shape of a Better Auth user record.
///
/// Kept separate from [AppUser] so a backend field rename is absorbed here and
/// nothing above the data layer changes.
class AppUserDto {
  const AppUserDto({
    required this.id,
    required this.name,
    this.email,
    this.phoneNumber,
    this.role,
    this.image,
  });

  factory AppUserDto.fromJson(Map<String, dynamic> json) {
    return AppUserDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      role: json['role']?.toString(),
      image: json['image']?.toString(),
    );
  }

  final String id;
  final String name;
  final String? email;
  final String? phoneNumber;
  final String? role;
  final String? image;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phoneNumber': phoneNumber,
    'role': role,
    'image': image,
  };

  AppUser toEntity() => AppUser(
    id: id,
    name: name.isEmpty ? (email ?? phoneNumber ?? 'Unknown') : name,
    role: appRoleFromName(role),
    // Better Auth stores a placeholder address for OTP-provisioned guardians;
    // showing `9048…@guardian.najath.local` in the profile header would be
    // worse than showing nothing.
    email: (email?.endsWith('@guardian.najath.local') ?? false) ? null : email,
    phoneNumber: phoneNumber,
    imageUrl: image,
  );
}
