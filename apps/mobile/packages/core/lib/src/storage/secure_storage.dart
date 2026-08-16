import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin contract over the platform keystore, so tests can substitute an
/// in-memory implementation without a plugin channel.
abstract class SecureStorage {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
  Future<void> deleteAll();
  Future<bool> containsKey({required String key});
}

class SecureStorageImpl implements SecureStorage {
  SecureStorageImpl(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();

  @override
  Future<bool> containsKey({required String key}) => _storage.containsKey(key: key);
}

/// In-memory stand-in for tests and for the `flutter test` environment, where
/// the secure-storage plugin has no platform side.
class InMemorySecureStorage implements SecureStorage {
  final Map<String, String> _values = {};

  @override
  Future<void> write({required String key, required String value}) async => _values[key] = value;

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> delete({required String key}) async => _values.remove(key);

  @override
  Future<void> deleteAll() async => _values.clear();

  @override
  Future<bool> containsKey({required String key}) async => _values.containsKey(key);
}

final secureStorageProvider = Provider<SecureStorage>((ref) {
  const storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  return SecureStorageImpl(storage);
});
