import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_network/najath_network.dart';

import '../models/access_policy_dto.dart';
import '../models/app_user_dto.dart';

/// The Better Auth session payload: a bearer token plus the user record.
class SignInResult {
  const SignInResult({required this.token, required this.user});

  final String token;
  final AppUserDto user;
}

class AuthRemoteSource {
  AuthRemoteSource(this._client);

  final DioClient _client;

  Future<ApiResponse<SignInResult>> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _client.post<SignInResult>(
      endpoint: ApiEndpoints.signInEmail,
      isAuth: true,
      data: {'email': email, 'password': password},
      mapper: _mapSignIn,
    );
  }

  Future<ApiResponse<void>> requestPhoneOtp(String phoneNumber) {
    return _client.post<void>(
      endpoint: ApiEndpoints.phoneOtpSend,
      isAuth: true,
      data: {'phoneNumber': phoneNumber},
      mapper: (_) {},
    );
  }

  Future<ApiResponse<SignInResult>> verifyPhoneOtp({
    required String phoneNumber,
    required String code,
  }) {
    return _client.post<SignInResult>(
      endpoint: ApiEndpoints.phoneOtpVerify,
      isAuth: true,
      data: {'phoneNumber': phoneNumber, 'code': code},
      mapper: _mapSignIn,
    );
  }

  /// Re-reads the session. The bearer token is attached by `DioClient`, so a
  /// 401 here means the session record is gone server-side.
  Future<ApiResponse<AppUserDto>> session() {
    return _client.get<AppUserDto>(
      endpoint: ApiEndpoints.session,
      isAuth: true,
      mapper: (body) {
        final map = body as Map<String, dynamic>;
        final user = map['user'];
        if (user is! Map<String, dynamic>) {
          throw const FormatException('session response carried no user');
        }
        return AppUserDto.fromJson(user);
      },
    );
  }

  Future<ApiResponse<void>> signOut() {
    return _client.post<void>(
      endpoint: ApiEndpoints.signOut,
      isAuth: true,
      mapper: (_) {},
    );
  }

  Future<ApiResponse<AccessPolicyDto>> accessPolicy() {
    return _client.get<AccessPolicyDto>(
      endpoint: ApiEndpoints.myAccess,
      mapper: (body) => AccessPolicyDto.fromJson(body as Map<String, dynamic>),
    );
  }

  /// Better Auth returns the bearer token in a `set-auth-token` header for
  /// non-cookie clients, and also inlines it in the body for the bearer plugin.
  /// Read the body form — Dio hands us the parsed JSON, not the headers, at
  /// this layer.
  SignInResult _mapSignIn(dynamic body) {
    final map = body as Map<String, dynamic>;
    final token = map['token']?.toString();
    final user = map['user'];
    if (token == null || token.isEmpty) {
      throw const FormatException('sign-in response carried no token');
    }
    if (user is! Map<String, dynamic>) {
      throw const FormatException('sign-in response carried no user');
    }
    return SignInResult(token: token, user: AppUserDto.fromJson(user));
  }
}

final authRemoteSourceProvider = Provider<AuthRemoteSource>((ref) {
  return AuthRemoteSource(ref.watch(dioClientProvider));
});
