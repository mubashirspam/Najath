/// Logical partitions of the offline cache.
///
/// The local database stores one JSON document per row inside a named box, the
/// same shape Telios used with Hive — the box name is just a column here, so
/// adding a partition costs nothing and no schema migration.
class CacheBoxes {
  CacheBoxes._();

  static const String classes = 'classes';
  static const String students = 'students';
  static const String attendanceSessions = 'attendance_sessions';
  static const String attendanceMarks = 'attendance_marks';
  static const String hifzEntries = 'hifz_entries';
  static const String hifzProgress = 'hifz_progress';
  static const String examResults = 'exam_results';
  static const String leaveRequests = 'leave_requests';
  static const String hostel = 'hostel';
  static const String canteen = 'canteen';
  static const String announcements = 'announcements';
  static const String activities = 'activities';
  static const String profile = 'profile';

  /// One-time "this has been synced" markers written by the sync engine.
  static const String syncState = 'sync_state';

  /// User preferences that must survive a cache clear.
  static const String settings = 'settings';

  static const List<String> all = [
    classes,
    students,
    attendanceSessions,
    attendanceMarks,
    hifzEntries,
    hifzProgress,
    examResults,
    leaveRequests,
    hostel,
    canteen,
    announcements,
    activities,
    profile,
    syncState,
    settings,
  ];

  /// Boxes wiped by Settings → Clear cache.
  ///
  /// [settings] is kept because it holds preferences, not cached server data.
  /// The outbox is a separate table and is never cleared here — an unsent
  /// attendance mark is the user's work, not a cache.
  static const List<String> clearable = [
    classes,
    students,
    attendanceSessions,
    attendanceMarks,
    hifzEntries,
    hifzProgress,
    examResults,
    leaveRequests,
    hostel,
    canteen,
    announcements,
    activities,
    profile,
    syncState,
  ];
}
