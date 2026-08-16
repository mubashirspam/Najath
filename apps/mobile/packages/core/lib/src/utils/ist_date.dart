/// Calendar dates in `Asia/Kolkata`.
///
/// Two different things live in this system and are handled differently:
///
/// * **Timestamps** — `markedAt`, `loggedAt` — are instants. UTC, always.
/// * **Dates** — attendance date, hifz log date, leave from/to — are calendar
///   facts about a school day, and belong to the institution's timezone.
///
/// **Never derive a date from a UTC timestamp.**
/// `DateTime.now().toUtc().toIso8601String().substring(0, 10)` is wrong: at
/// 06:00 IST it returns yesterday, so a teacher marking a Fajr halaqa files the
/// log against the wrong day — and the correction lands on the wrong day too.
///
/// India has no daylight saving and a fixed +05:30 offset, so a fixed offset is
/// correct here and avoids a timezone database in the app. If the platform ever
/// serves a second country, this becomes a lookup and every call site already
/// goes through it.
class IstDate {
  IstDate._();

  /// India Standard Time. Fixed — no DST, no historical changes in scope.
  static const Duration offset = Duration(hours: 5, minutes: 30);

  /// Today in Asia/Kolkata, as `YYYY-MM-DD`.
  static String today() => from(DateTime.now());

  /// The calendar date [instant] falls on in Asia/Kolkata.
  static String from(DateTime instant) {
    final ist = instant.toUtc().add(offset);
    return _format(ist);
  }

  /// [days] before today, for "last 7 days" style ranges.
  static String daysAgo(int days) => from(DateTime.now().subtract(Duration(days: days)));

  /// Parses `YYYY-MM-DD` into the UTC instant that date *starts* at in IST.
  ///
  /// Used when a date has to become a range boundary for a timestamp query.
  static DateTime? startOfDayUtc(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return null;

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;

    return DateTime.utc(year, month, day).subtract(offset);
  }

  /// Whether a `YYYY-MM-DD` string is today in IST. The check behind "a teacher
  /// may edit attendance the same day only".
  static bool isToday(String date) => date == today();

  /// Days between two `YYYY-MM-DD` strings, or null if either is malformed.
  /// Drives the backdating limit on hifz logs.
  static int? daysBetween(String from, String to) {
    final start = startOfDayUtc(from);
    final end = startOfDayUtc(to);
    if (start == null || end == null) return null;
    return end.difference(start).inDays;
  }

  static String _format(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
