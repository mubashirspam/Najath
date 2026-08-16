/// Build flavors. Mirrors the Android/iOS product flavors created by
/// flutter_flavorizr and the `--flavor` passed to `flutter run`.
enum Environment { dev, staging, prod }

/// Immutable per-environment configuration.
///
/// Values come from `--dart-define-from-file=config/<flavor>.json`, so the same
/// binary shape is used everywhere and nothing environment-specific is compiled
/// into a `const` table that someone has to remember to edit.
class EnvConfig {
  const EnvConfig({
    required this.env,
    required this.apiBaseUrl,
    required this.enableLogging,
  });

  /// Reads the values injected by `--dart-define-from-file`.
  ///
  /// [flavor] comes from the platform build (Flutter's `appFlavor`), not from
  /// the JSON, so a dev config accidentally shipped in a prod build still
  /// reports the truth.
  factory EnvConfig.fromDartDefines(Environment flavor) {
    return EnvConfig(
      env: flavor,
      apiBaseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://10.0.2.2:3000/api/v1',
      ),
      enableLogging: bool.fromEnvironment(
        'ENABLE_LOGGING',
        defaultValue: flavor != Environment.prod,
      ),
    );
  }

  final Environment env;

  /// Root of the Next.js API, including the `/api/v1` prefix.
  final String apiBaseUrl;

  /// Turns on Dio request/response logging. Never enable in prod — request
  /// bodies carry guardian phone numbers and student records.
  final bool enableLogging;

  /// Root that Better Auth is mounted under.
  ///
  /// The REST API lives at `/api/v1` but Better Auth mounts itself at
  /// `/api/auth`, one level up, so the auth calls resolve against this instead
  /// of [apiBaseUrl].
  String get authBaseUrl {
    var base = apiBaseUrl;
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base.endsWith('/v1') ? base.substring(0, base.length - 3) : base;
  }

  bool get isDev => env == Environment.dev;
  bool get isStaging => env == Environment.staging;
  bool get isProd => env == Environment.prod;

  /// Staging and dev share a database, so both are treated as non-production
  /// for anything that gates destructive or diagnostic affordances.
  bool get isNonProduction => env != Environment.prod;
}
