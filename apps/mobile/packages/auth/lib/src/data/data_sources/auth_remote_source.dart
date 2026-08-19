import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_network/najath_network.dart';

import '../models/access_policy_dto.dart';
import '../models/app_user_dto.dart';
import '../models/session_dto.dart';

/// The Better Auth session payload: a bearer token plus the user record.
class SignInResult {
  const SignInResult({required this.token, required this.user});

  final String token;
  final AppUserDto user;
}

class AuthRemoteSource {
  AuthRemoteSource(this._client);

  final DioClient _client;

  Future<Result<SignInResult>> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _client.post<SignInResult>(
      endpoint: ApiEndpoints.signInEmail,
      isAuth: true,
      data: {'email': email, 'password': password},
      decode: _mapSignIn,
    );
  }

  Future<Result<void>> requestPhoneOtp(String phoneNumber) {
    return _client.post<void>(
      endpoint: ApiEndpoints.phoneOtpSend,
      isAuth: true,
      data: {'phoneNumber': phoneNumber},
      decode: (_) {},
    );
  }

  Future<Result<SignInResult>> verifyPhoneOtp({
    required String phoneNumber,
    required String code,
  }) {
    return _client.post<SignInResult>(
      endpoint: ApiEndpoints.phoneOtpVerify,
      isAuth: true,
      data: {'phoneNumber': phoneNumber, 'code': code},
      decode: _mapSignIn,
    );
  }

  /// Re-reads the session, including the access policy.
  ///
  /// The bearer token is attached by `DioClient`, so a 401 here means the
  /// session record is gone server-side — the only condition that signs a user
  /// out. Anything else leaves the stored session alone.
  Future<Result<SessionDto>> session() {
    return _client.get<SessionDto>(
      endpoint: ApiEndpoints.session,
      decode: (body) => SessionDto.fromJson(body as Map<String, dynamic>),
    );
  }

  Future<Result<void>> signOut() {
    return _client.post<void>(
      endpoint: ApiEndpoints.signOut,
      isAuth: true,
      decode: (_) {},
    );
  }

  Future<Result<AccessPolicyDto>> accessPolicy() {
    return _client.get<AccessPolicyDto>(
      endpoint: ApiEndpoints.myAccess,
      decode: (body) => AccessPolicyDto.fromJson(body as Map<String, dynamic>),
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
