import 'package:najath_core/najath_core.dart';

/// Central URL builders.
///
/// Navigation state lives in the URL — query params, not ad-hoc arguments — so
/// a push notification deep link, a cold start, or a restored session all land
/// on exactly the screen the user expected. Screens never assemble URLs by
/// hand.
class RoutePath {
  RoutePath._();

  static const String splash = '/';
  static const String login = '/login';
  static const String noAccess = '/no-access';

  static String home({int tabIndex = 0}) => '/home?t=$tabIndex';

  static String attendance() => '/home/attendance';

  static String attendanceRoster({
    required String sessionId,
    required String title,
    bool isFinalised = false,
  }) =>
      '/home/attendance/roster?id=$sessionId'
      '&title=${Uri.encodeComponent(title)}'
      '&final=$isFinalised';

  static String hifz() => '/home/hifz';
  static String academics() => '/home/academics';
  static String exams() => '/home/exams';
  static String progress() => '/home/progress';
  static String leave() => '/home/leave';
  static String hostel() => '/home/hostel';
  static String canteen() => '/home/canteen';
  static String activities() => '/home/activities';
  static String announcements() => '/home/announcements';
  static String profile() => '/home/profile';
  static String settings() => '/home/settings';
  static String unsynced() => '/home/unsynced';

  /// The route a screen id navigates to.
  ///
  /// The nav shell is built from the access policy, which knows screen ids and
  /// nothing about URLs — this is the one place the two vocabularies meet.
  static String forScreen(String screenId) => switch (screenId) {
    ScreenId.dashboard => home(),
    ScreenId.attendance => attendance(),
    ScreenId.hifz => hifz(),
    ScreenId.academics => academics(),
    ScreenId.exams => exams(),
    ScreenId.progress => progress(),
    ScreenId.leave => leave(),
    ScreenId.hostel => hostel(),
    ScreenId.canteen => canteen(),
    ScreenId.activities => activities(),
    ScreenId.announcements => announcements(),
    ScreenId.profile => profile(),
    _ => home(),
  };
}
