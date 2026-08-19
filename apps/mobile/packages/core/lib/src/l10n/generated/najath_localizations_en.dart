// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'najath_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Najath';

  @override
  String get appTagline => 'Quran Academy';

  @override
  String get actionTryAgain => 'Try again';

  @override
  String get actionGoBack => 'Go back';

  @override
  String get actionSignIn => 'Sign in';

  @override
  String get actionSignOut => 'Sign out';

  @override
  String get actionSendCode => 'Send code';

  @override
  String get actionVerifyCode => 'Verify code';

  @override
  String get actionResendCode => 'Send the code again';

  @override
  String get actionDiscard => 'Discard';

  @override
  String get actionTryNow => 'Try now';

  @override
  String get failureOffline => 'Not available offline yet';

  @override
  String get failureTimeout => 'The server took too long to respond';

  @override
  String get failureSessionEnded => 'Your session has ended';

  @override
  String get failureForbidden => 'You do not have access to this';

  @override
  String get failureValidation => 'Some details need correcting';

  @override
  String get failureConflict => 'This was changed somewhere else';

  @override
  String get failureNotFound => 'Not found';

  @override
  String get failureServer => 'Something went wrong at our end';

  @override
  String get failureUnknown => 'Something went wrong';

  @override
  String get failureOfflineHint => 'This will load once you are back online.';

  @override
  String get offlineShowingSaved => 'Offline — showing saved data';

  @override
  String offlinePendingWrites(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Offline — $count changes will send when you reconnect',
      one: 'Offline — 1 change will send when you reconnect',
    );
    return '$_temp0';
  }

  @override
  String get syncSending => 'Sending your changes…';

  @override
  String syncSendingItem(String label) {
    return 'Sending $label…';
  }

  @override
  String get syncUpdating => 'Updating…';

  @override
  String syncUpdatingItem(String label) {
    return 'Updating $label…';
  }

  @override
  String get syncUpToDate => 'Everything is up to date';

  @override
  String get syncCouldNotFinish => 'Sync could not finish';

  @override
  String get syncFallbackPolicy =>
      'Showing default access — connect once to load your academy settings.';

  @override
  String get noAccessTitle => 'No access';

  @override
  String noAccessBody(String section) {
    return 'You do not have access to $section';
  }

  @override
  String get noAccessSectionFallback => 'this section';

  @override
  String get noAccessHint =>
      'Access is managed by the academy office. Ask them to enable it for your role if you need it.';

  @override
  String get noSectionsEnabled =>
      'Your account has no sections enabled yet.\nThe academy office can turn them on for your role.';

  @override
  String get loginStaffTab => 'Staff';

  @override
  String get loginParentTab => 'Guardian';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginPhone => 'Phone number';

  @override
  String get loginOtpCode => 'Six-digit code';

  @override
  String get loginRememberMe => 'Remember me';

  @override
  String get loginEnterEmail => 'Enter your email';

  @override
  String get loginEnterPhone => 'Enter your phone number';

  @override
  String get loginEnterPassword => 'Enter your password';

  @override
  String get loginEnterCode => 'Enter the code we sent you';

  @override
  String get loginInvalidEmail => 'That does not look like an email';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsYourAccess => 'Your access';

  @override
  String settingsAccessSummary(int screens, int permissions) {
    String _temp0 = intl.Intl.pluralLogic(
      screens,
      locale: localeName,
      other: '$screens sections',
      one: '1 section',
    );
    return '$_temp0 · $permissions permissions';
  }

  @override
  String get settingsAccessDefaults => 'defaults';

  @override
  String get settingsRefreshAccess => 'Refresh access';

  @override
  String get settingsRefreshAccessHint => 'Pick up changes made by the academy office';

  @override
  String get settingsAccessRefreshed => 'Access refreshed';

  @override
  String get settingsClearCache => 'Clear cached data';

  @override
  String get settingsClearCacheHint => 'Keeps anything not yet sent';

  @override
  String get settingsCacheCleared => 'Cached data cleared';

  @override
  String get settingsSections => 'Sections';

  @override
  String get settingsSwitchRole => 'Switch role';

  @override
  String get unsyncedTitle => 'Unsynced work';

  @override
  String get unsyncedAllSent => 'Everything has been sent';

  @override
  String get unsyncedWaiting => 'Waiting to send';

  @override
  String unsyncedRetrying(int attempts) {
    String _temp0 = intl.Intl.pluralLogic(
      attempts,
      locale: localeName,
      other: 'Retrying — $attempts attempts so far',
      one: 'Retrying — 1 attempt so far',
    );
    return '$_temp0';
  }

  @override
  String get unsyncedRejected => 'Rejected by the server';

  @override
  String get attendanceReadOnly => 'You can view this roster but not change it.';

  @override
  String get attendanceWillSend => 'Will send when online';

  @override
  String get attendanceNotMarked => 'Not marked';

  @override
  String get attendanceNoStudents => 'No students enrolled in this batch';

  @override
  String attendanceMarkedOfTotal(int marked, int total) {
    return '$marked of $total';
  }

  @override
  String get attendancePresent => 'Present';

  @override
  String get attendanceAbsent => 'Absent';

  @override
  String get attendanceLate => 'Late';

  @override
  String get attendanceExcused => 'Excused';

  @override
  String get attendanceOnLeave => 'On leave';

  @override
  String get roleSuperAdmin => 'System administrator';

  @override
  String get roleAdmin => 'Office admin';

  @override
  String get roleDeptHead => 'Department head';

  @override
  String get roleTeacher => 'Teacher';

  @override
  String get roleHostelWarden => 'Hostel warden';

  @override
  String get roleCanteenManager => 'Canteen manager';

  @override
  String get roleAccountant => 'Accountant';

  @override
  String get roleParent => 'Parent';

  @override
  String get screenToday => 'Today';

  @override
  String get screenBatches => 'Batches';

  @override
  String get screenBatchAttendance => 'Take attendance';

  @override
  String get screenBatchHifz => 'Hifz log';

  @override
  String get screenMarksEntry => 'Marks entry';

  @override
  String get screenLeaveApprovals => 'Leave approvals';

  @override
  String get screenStudentDetail => 'Student';

  @override
  String get screenTeacherReports => 'Reports';

  @override
  String get screenWards => 'Wards';

  @override
  String get screenWardAttendance => 'Attendance';

  @override
  String get screenWardHifz => 'Hifz';

  @override
  String get screenWardHifzHistory => 'Hifz history';

  @override
  String get screenWardDoura => 'Doura';

  @override
  String get screenWardAcademics => 'Academics';

  @override
  String get screenWardHomework => 'Homework';

  @override
  String get screenWardResults => 'Results';

  @override
  String get screenWardActivities => 'Activities';

  @override
  String get screenWardLeave => 'Leave';

  @override
  String get screenWardHostel => 'Hostel';

  @override
  String get screenWardCanteen => 'Canteen';

  @override
  String get screenWardReports => 'Progress reports';

  @override
  String get screenNotices => 'Notices';

  @override
  String get screenRollcall => 'Roll call';

  @override
  String get screenGatePass => 'Gate pass';

  @override
  String get screenOccupancy => 'Occupancy';

  @override
  String get screenVisitors => 'Visitors';
}
