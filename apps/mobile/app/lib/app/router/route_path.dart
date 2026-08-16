import 'package:najath_core/najath_core.dart';

/// Central URL builders, grouped by shell.
///
/// Navigation state lives in the URL — path segments for identity, query params
/// for view state — so a push notification deep link, a cold start, or a
/// restored session all land on exactly the screen the user expected. Screens
/// never assemble URLs by hand.
class RoutePath {
  RoutePath._();

  static const String splash = '/';
  static const String login = '/login';
  static const String noAccess = '/no-access';
  static const String settings = '/settings';
  static const String unsynced = '/unsynced';

  // ── Teacher shell ──────────────────────────────────────────────────────────
  static const String today = '/today';
  static const String batches = '/batches';
  static const String teacherReports = '/reports';
  static const String leaveApprovals = '/leave/approvals';

  static String batchAttendance(String batchId) => '/batches/$batchId/attendance';
  static String batchHifz(String batchId, {String activity = 'SABAQ'}) =>
      '/batches/$batchId/hifz?activity=$activity';
  static String hifzQuickLog(String batchId, String enrollmentId) =>
      '/batches/$batchId/hifz/$enrollmentId';
  static String marksEntry(String classSectionId, String examId) =>
      '/classes/$classSectionId/marks/$examId';
  static String student(String studentId) => '/students/$studentId';

  // ── Parent shell — every route carries the selected ward ───────────────────
  static const String wards = '/wards';
  static const String notices = '/notices';

  static String ward(String studentId) => '/wards/$studentId';
  static String wardAttendance(String studentId) => '/wards/$studentId/attendance';
  static String wardHifz(String studentId) => '/wards/$studentId/hifz';
  static String wardHifzHistory(String studentId) => '/wards/$studentId/hifz/history';
  static String wardDoura(String studentId) => '/wards/$studentId/hifz/doura';
  static String wardAcademics(String studentId) => '/wards/$studentId/academics';
  static String wardHomework(String studentId) => '/wards/$studentId/homework';
  static String wardResults(String studentId) => '/wards/$studentId/results';
  static String wardActivities(String studentId) => '/wards/$studentId/activities';
  static String wardLeave(String studentId) => '/wards/$studentId/leave';
  static String wardHostel(String studentId) => '/wards/$studentId/hostel';
  static String wardCanteen(String studentId) => '/wards/$studentId/canteen';
  static String wardReports(String studentId) => '/wards/$studentId/reports';

  // ── Hostel shell ───────────────────────────────────────────────────────────
  static const String rollcall = '/rollcall';
  static const String gatePass = '/gate-pass';
  static const String occupancy = '/occupancy';
  static const String visitors = '/visitors';

  /// The route a screen id navigates to.
  ///
  /// The nav shell is built from the access policy, which knows screen ids and
  /// nothing about URLs — this is the one place the two vocabularies meet.
  /// Ward-scoped screens need the selected ward, so they take it here.
  static String forScreen(String screenId, {String? wardId}) {
    final ward = wardId ?? '';
    return switch (screenId) {
      ScreenId.today => today,
      ScreenId.batches => batches,
      ScreenId.batchHifz => batches,
      ScreenId.teacherReports => teacherReports,
      ScreenId.leaveApprovals => leaveApprovals,
      ScreenId.wards => wards,
      ScreenId.wardHifz => ward.isEmpty ? wards : wardHifz(ward),
      ScreenId.wardAcademics => ward.isEmpty ? wards : wardAcademics(ward),
      ScreenId.wardLeave => ward.isEmpty ? wards : wardLeave(ward),
      ScreenId.notices => notices,
      ScreenId.rollcall => rollcall,
      ScreenId.gatePass => gatePass,
      ScreenId.occupancy => occupancy,
      ScreenId.visitors => visitors,
      _ => today,
    };
  }
}
