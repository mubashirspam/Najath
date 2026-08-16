/// Timeouts, debounces and pacing gaps, in one place so they can be reasoned
/// about together rather than rediscovered at each call site.
class AppDurations {
  AppDurations._();

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Search-as-you-type and filter inputs.
  static const Duration searchDebounce = Duration(milliseconds: 350);

  /// Gap between successive background sync requests, so the screen the user is
  /// looking at always wins the race for a Dio connection.
  static const Duration syncPaceGap = Duration(milliseconds: 250);

  /// Larger gap for bulk payloads (media, the ayah index) that trickle in.
  static const Duration syncBulkPaceGap = Duration(milliseconds: 400);

  /// How long the "all synced" confirmation lingers before the banner hides.
  static const Duration syncDoneLinger = Duration(seconds: 3);

  /// How stale a cached access policy may get before a refresh is forced while
  /// online. Offline, the cached policy is used regardless of age.
  static const Duration accessPolicyMaxAge = Duration(hours: 12);
}
