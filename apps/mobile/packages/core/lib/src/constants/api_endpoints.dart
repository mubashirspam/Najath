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
  static const String session = '/auth/get-session';
  static const String phoneOtpSend = '/auth/phone-number/send-otp';
  static const String phoneOtpVerify = '/auth/phone-number/verify';

  // --- Identity / access ---------------------------------------------------
  /// Role, permission set and allowed screens for the signed-in principal.
  static const String myAccess = '/me/access';
  static const String myProfile = '/me/profile';

  // --- Academics -----------------------------------------------------------
  static const String classes = '/academics/classes';
  static String classById(String id) => '/academics/classes/$id';
  static const String students = '/academics/students';
  static String studentById(String id) => '/academics/students/$id';

  // --- Attendance ----------------------------------------------------------
  static const String attendanceSessions = '/attendance/sessions';
  static String attendanceSessionById(String id) => '/attendance/sessions/$id';
  static String attendanceMarks(String sessionId) => '/attendance/sessions/$sessionId/marks';

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
