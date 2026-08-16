import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'env.dart';

/// Static access to the active environment.
///
/// Assigned once in `bootstrap()` before anything reads it. Static rather than
/// provider-only because infrastructure — Dio base options, the router's
/// redirect guard — needs it outside the widget tree.
class Env {
  Env._();

  static EnvConfig current = EnvConfig.fromDartDefines(Environment.dev);

  static String get apiBaseUrl => current.apiBaseUrl;
  static bool get enableLogging => current.enableLogging;
  static bool get isDev => current.isDev;
  static bool get isProd => current.isProd;
  static bool get isNonProduction => current.isNonProduction;
}

/// The same config, for the widget tree. Overridden in `ProviderScope` at
/// bootstrap so tests can inject their own without touching the static.
final envConfigProvider = Provider<EnvConfig>((ref) => Env.current);
