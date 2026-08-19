/// Every backend path the app talks to, relative to `EnvConfig.apiBaseUrl`.
///
/// Centralised so a route rename on the Next.js side is a one-file change here
/// and so no path string is ever assembled at a call site.
class ApiEndpoints {
  ApiEndpoints._();

  // --- Better Auth ---------------------------------------------------------
  // Better Auth mounts itself at /api/auth, i.e. one level above /api/v1, so
  // these are written absolute-from-origin and resolved by DioClient.
  static const String signInEmail = '/auth/sign-in/email';
  static const String signOut = '/auth/sign-out';

  /// Better Auth's own session probe. The app prefers [session] below, which
  /// returns the access policy in the same round trip.
  static const String authSession = '/auth/get-session';
  static const String phoneOtpSend = '/auth/phone-number/send-otp';
  static const String phoneOtpVerify = '/auth/phone-number/verify';

  // --- Identity / access ---------------------------------------------------
  /// User, roles, scopes, screens and shell in one request — what the mobile
  /// shell is built from on every cold start.
  static const String session = '/session';

  /// Role, permission set and allowed screens for the signed-in principal.
  static const String myAccess = '/me/access';
  static const String myProfile = '/me/profile';

  // --- Academics -----------------------------------------------------------
  static const String classes = '/academics/classes';
  static String classById(String id) => '/academics/classes/$id';
  static const String students = '/academics/students';
  static String studentById(String id) => '/academics/students/$id';

  // --- Attendance ----------------------------------------------------------
  static const String attendanceRoster = '/attendance/roster';
  static const String attendanceBatch = '/attendance/batch';
  static String attendanceForEnrollment(String enrollmentId) => '/attendance/student/$enrollmentId';
  static const String attendanceSummary = '/attendance/summary';
  static String attendanceCorrect(String id) => '/attendance/$id/correct';

  // --- Hifz ----------------------------------------------------------------
  static String hifzProgress(String studentId) => '/hifz/$studentId/progress';
  static const String hifzEntries = '/hifz/entries';

  // --- Exams ---------------------------------------------------------------
  static String examResults(String studentId) => '/exams/$studentId/results';

  // --- Leave ---------------------------------------------------------------
  static const String leaveRequests = '/leave/requests';
  static String leaveRequestById(String id) => '/leave/requests/$id';

  // --- Comms ---------------------------------------------------------------
  static const String announcements = '/announcements';
  static const String deviceTokens = '/me/device-tokens';
}
