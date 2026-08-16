/// Keys used in `flutter_secure_storage`. Centralised so a key is never
/// duplicated as a literal and so `deleteAll` semantics stay auditable.
class SecureStorageKeys {
  SecureStorageKeys._();

  static const String accessToken = 'najath.access_token';
  static const String userId = 'najath.user_id';
  static const String userJson = 'najath.user';

  /// The last access policy fetched from the server, kept here rather than in
  /// the cache database because it is the thing that decides what a user may
  /// see and should not survive an app data wipe of the general cache.
  static const String accessPolicyJson = 'najath.access_policy';
  static const String accessPolicyFetchedAt = 'najath.access_policy_at';

  static const String themeMode = 'najath.theme_mode';
  static const String locale = 'najath.locale';
  static const String rememberMe = 'najath.remember_me';
  static const String savedIdentifier = 'najath.saved_identifier';
}
