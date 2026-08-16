import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/secure_storage_keys.dart';
import 'secure_storage.dart';

/// Typed facade over [SecureStorage].
///
/// Everything that must survive a restart but must not sit in the plaintext
/// cache database lives here: the bearer token, the identity of the signed-in
/// principal, and the access policy that decides what they can see.
class TokenStorage {
  TokenStorage(this._storage);

  final SecureStorage _storage;

  // --- session -------------------------------------------------------------

  Future<void> saveToken(String token) =>
      _storage.write(key: SecureStorageKeys.accessToken, value: token);

  Future<String?> getToken() => _storage.read(key: SecureStorageKeys.accessToken);

  Future<void> saveUserId(String userId) =>
      _storage.write(key: SecureStorageKeys.userId, value: userId);

  Future<String?> getUserId() => _storage.read(key: SecureStorageKeys.userId);

  Future<void> saveUserJson(Map<String, dynamic> user) =>
      _storage.write(key: SecureStorageKeys.userJson, value: jsonEncode(user));

  Future<Map<String, dynamic>?> getUserJson() async {
    final raw = await _storage.read(key: SecureStorageKeys.userJson);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on Object catch (_) {
      return null;
    }
  }

  /// Drops everything session-scoped, including the access policy — a new
  /// principal must never inherit the previous one's screens.
  Future<void> clearSession() async {
    await _storage.delete(key: SecureStorageKeys.accessToken);
    await _storage.delete(key: SecureStorageKeys.userId);
    await _storage.delete(key: SecureStorageKeys.userJson);
    await _storage.delete(key: SecureStorageKeys.accessPolicyJson);
    await _storage.delete(key: SecureStorageKeys.accessPolicyFetchedAt);
  }

  // --- access policy -------------------------------------------------------

  Future<void> saveAccessPolicy(Map<String, dynamic> policy) async {
    await _storage.write(
      key: SecureStorageKeys.accessPolicyJson,
      value: jsonEncode(policy),
    );
    await _storage.write(
      key: SecureStorageKeys.accessPolicyFetchedAt,
      value: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<Map<String, dynamic>?> getAccessPolicy() async {
    final raw = await _storage.read(key: SecureStorageKeys.accessPolicyJson);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on Object catch (_) {
      return null;
    }
  }

  Future<DateTime?> getAccessPolicyFetchedAt() async {
    final raw = await _storage.read(key: SecureStorageKeys.accessPolicyFetchedAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  // --- preferences ---------------------------------------------------------

  Future<void> saveThemeMode(ThemeMode mode) =>
      _storage.write(key: SecureStorageKeys.themeMode, value: mode.name);

  Future<ThemeMode> getThemeMode() async {
    final raw = await _storage.read(key: SecureStorageKeys.themeMode);
    return ThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> saveRememberMe({
    required bool remember,
    String? identifier,
  }) async {
    await _storage.write(
      key: SecureStorageKeys.rememberMe,
      value: remember.toString(),
    );
    if (remember && identifier != null) {
      await _storage.write(
        key: SecureStorageKeys.savedIdentifier,
        value: identifier,
      );
    } else {
      await _storage.delete(key: SecureStorageKeys.savedIdentifier);
    }
  }

  Future<bool> getRememberMe() async =>
      (await _storage.read(key: SecureStorageKeys.rememberMe)) == 'true';

  Future<String?> getSavedIdentifier() => _storage.read(key: SecureStorageKeys.savedIdentifier);
}

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(ref.watch(secureStorageProvider));
});
