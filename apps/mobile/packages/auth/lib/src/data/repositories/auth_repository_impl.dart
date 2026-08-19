import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../data_sources/auth_remote_source.dart';
import '../models/app_user_dto.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteSource remote,
    required TokenStorage storage,
  }) : _remote = remote,
       _storage = storage;

  final AuthRemoteSource _remote;
  final TokenStorage _storage;

  @override
  Future<Result<AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final res = await _remote.signInWithEmail(email: email, password: password);
    return _persist(res);
  }

  @override
  Future<Result<void>> requestPhoneOtp(String phoneNumber) => _remote.requestPhoneOtp(phoneNumber);

  @override
  Future<Result<AppUser>> verifyPhoneOtp({
    required String phoneNumber,
    required String code,
  }) async {
    final res = await _remote.verifyPhoneOtp(
      phoneNumber: phoneNumber,
      code: code,
    );
    return _persist(res);
  }

  @override
  Future<Result<({AppUser user, AccessPolicy policy})>> currentSession() async {
    final res = await _remote.session();
    final failure = res.failureOrNull;
    if (failure != null) return fail(failure);

    final dto = res.valueOrNull!;
    await _storage.saveUserId(dto.user.id);
    await _storage.saveUserJson(dto.user.toJson());
    // Persist the policy from the same response, so the next offline launch
    // has it without a second request that may never succeed.
    await _storage.saveAccessPolicy(dto.policy.toJson());
    return ok((user: dto.user.toEntity(), policy: dto.toPolicy()));
  }

  @override
  Future<AppUser?> cachedUser() async {
    final json = await _storage.getUserJson();
    if (json == null) return null;
    return AppUserDto.fromJson(json).toEntity();
  }

  @override
  Future<bool> hasStoredSession() async {
    final token = await _storage.getToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<void> signOut() async {
    // Tell the server first so the session row is revoked, but clear locally
    // whatever happens — a user signing out on a plane must still be signed out.
    await _remote.signOut();
    await _storage.clearSession();
  }

  @override
  Future<void> saveRememberMe({required bool remember, String? identifier}) =>
      _storage.saveRememberMe(remember: remember, identifier: identifier);

  @override
  Future<bool> getRememberMe() => _storage.getRememberMe();

  @override
  Future<String?> savedIdentifier() => _storage.getSavedIdentifier();

  Future<Result<AppUser>> _persist(Result<SignInResult> res) async {
    final failure = res.failureOrNull;
    if (failure != null) return fail(failure);

    final result = res.valueOrNull!;
    await _storage.saveToken(result.token);
    await _storage.saveUserId(result.user.id);
    await _storage.saveUserJson(result.user.toJson());
    return ok(result.user.toEntity());
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: ref.watch(authRemoteSourceProvider),
    storage: ref.watch(tokenStorageProvider),
  );
});
