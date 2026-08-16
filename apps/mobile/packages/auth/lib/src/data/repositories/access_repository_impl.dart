import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';

import '../../domain/repositories/auth_repository.dart';
import '../data_sources/auth_remote_source.dart';
import '../models/access_policy_dto.dart';

/// Offline-first access policy.
///
/// The policy is cached in secure storage rather than the cache database: it
/// decides what the user may see, so it should not be wiped by Settings →
/// Clear cache, and it should die with the session.
class AccessRepositoryImpl implements AccessRepository {
  AccessRepositoryImpl({
    required AuthRemoteSource remote,
    required TokenStorage storage,
  }) : _remote = remote,
       _storage = storage;

  final AuthRemoteSource _remote;
  final TokenStorage _storage;

  @override
  Future<AccessPolicy?> cached() async {
    final json = await _storage.getAccessPolicy();
    if (json == null) return null;
    final fetchedAt = await _storage.getAccessPolicyFetchedAt();
    return AccessPolicyDto.fromJson(json).toEntity(fetchedAt: fetchedAt);
  }

  @override
  Future<Result<AccessPolicy>> fetch() async {
    final res = await _remote.accessPolicy();
    final failure = res.failureOrNull;
    if (failure != null) return fail(failure);

    final dto = res.valueOrNull!;
    await _storage.saveAccessPolicy(dto.toJson());
    return ok(dto.toEntity(fetchedAt: DateTime.now()));
  }

  @override
  Future<void> clear() async {
    await _storage.saveAccessPolicy(const <String, dynamic>{});
  }

  @override
  Future<bool> isStale() async {
    final fetchedAt = await _storage.getAccessPolicyFetchedAt();
    if (fetchedAt == null) return true;
    return DateTime.now().difference(fetchedAt) > AppDurations.accessPolicyMaxAge;
  }
}

final accessRepositoryProvider = Provider<AccessRepository>((ref) {
  return AccessRepositoryImpl(
    remote: ref.watch(authRemoteSourceProvider),
    storage: ref.watch(tokenStorageProvider),
  );
});
