import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'najath_localizations_en.dart';
import 'najath_localizations_ml.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/najath_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ml'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Najath'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Quran Academy'**
  String get appTagline;

  /// No description provided for @actionTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionTryAgain;

  /// No description provided for @actionGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get actionGoBack;

  /// No description provided for @actionSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get actionSignIn;

  /// No description provided for @actionSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get actionSignOut;

  /// No description provided for @actionSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get actionSendCode;

  /// No description provided for @actionVerifyCode.
  ///
  /// In en, this message translates to:
  /// **'Verify code'**
  String get actionVerifyCode;

  /// No description provided for @actionResendCode.
  ///
  /// In en, this message translates to:
  /// **'Send the code again'**
  String get actionResendCode;

  /// No description provided for @actionDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get actionDiscard;

  /// No description provided for @actionTryNow.
  ///
  /// In en, this message translates to:
  /// **'Try now'**
  String get actionTryNow;

  /// No description provided for @failureOffline.
  ///
  /// In en, this message translates to:
  /// **'Not available offline yet'**
  String get failureOffline;

  /// No description provided for @failureTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to respond'**
  String get failureTimeout;

  /// No description provided for @failureSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended'**
  String get failureSessionEnded;

  /// No description provided for @failureForbidden.
  ///
  /// In en, this message translates to:
  /// **'You do not have access to this'**
  String get failureForbidden;

  /// No description provided for @failureValidation.
  ///
  /// In en, this message translates to:
  /// **'Some details need correcting'**
  String get failureValidation;

  /// No description provided for @failureConflict.
  ///
  /// In en, this message translates to:
  /// **'This was changed somewhere else'**
  String get failureConflict;

  /// No description provided for @failureNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get failureNotFound;

  /// No description provided for @failureServer.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong at our end'**
  String get failureServer;

  /// No description provided for @failureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get failureUnknown;

  /// No description provided for @failureOfflineHint.
  ///
  /// In en, this message translates to:
  /// **'This will load once you are back online.'**
  String get failureOfflineHint;

  /// No description provided for @offlineShowingSaved.
  ///
  /// In en, this message translates to:
  /// **'Offline — showing saved data'**
  String get offlineShowingSaved;

  /// No description provided for @offlinePendingWrites.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Offline — 1 change will send when you reconnect} other{Offline — {count} changes will send when you reconnect}}'**
  String offlinePendingWrites(int count);

  /// No description provided for @syncSending.
  ///
  /// In en, this message translates to:
  /// **'Sending your changes…'**
  String get syncSending;

  /// No description provided for @syncSendingItem.
  ///
  /// In en, this message translates to:
  /// **'Sending {label}…'**
  String syncSendingItem(String label);

  /// No description provided for @syncUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating…'**
  String get syncUpdating;

  /// No description provided for @syncUpdatingItem.
  ///
  /// In en, this message translates to:
  /// **'Updating {label}…'**
  String syncUpdatingItem(String label);

  /// No description provided for @syncUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Everything is up to date'**
  String get syncUpToDate;

  /// No description provided for @syncCouldNotFinish.
  ///
  /// In en, this message translates to:
  /// **'Sync could not finish'**
  String get syncCouldNotFinish;

  /// No description provided for @syncFallbackPolicy.
  ///
  /// In en, this message translates to:
  /// **'Showing default access — connect once to load your academy settings.'**
  String get syncFallbackPolicy;

  /// No description provided for @noAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'No access'**
  String get noAccessTitle;

  /// No description provided for @noAccessBody.
  ///
  /// In en, this message translates to:
  /// **'You do not have access to {section}'**
  String noAccessBody(String section);

  /// No description provided for @noAccessSectionFallback.
  ///
  /// In en, this message translates to:
  /// **'this section'**
  String get noAccessSectionFallback;

  /// No description provided for @noAccessHint.
  ///
  /// In en, this message translates to:
  /// **'Access is managed by the academy office. Ask them to enable it for your role if you need it.'**
  String get noAccessHint;

  /// No description provided for @noSectionsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Your account has no sections enabled yet.\nThe academy office can turn them on for your role.'**
  String get noSectionsEnabled;

  /// No description provided for @loginStaffTab.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get loginStaffTab;

  /// No description provided for @loginParentTab.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get loginParentTab;

  /// No description provided for @loginEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmail;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get loginPhone;

  /// No description provided for @loginOtpCode.
  ///
  /// In en, this message translates to:
  /// **'Six-digit code'**
  String get loginOtpCode;

  /// No description provided for @loginRememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get loginRememberMe;

  /// No description provided for @loginEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get loginEnterEmail;

  /// No description provided for @loginEnterPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get loginEnterPhone;

  /// No description provided for @loginEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get loginEnterPassword;

  /// No description provided for @loginEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code we sent you'**
  String get loginEnterCode;

  /// No description provided for @loginInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'That does not look like an email'**
  String get loginInvalidEmail;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsYourAccess.
  ///
  /// In en, this message translates to:
  /// **'Your access'**
  String get settingsYourAccess;

  /// No description provided for @settingsAccessSummary.
  ///
  /// In en, this message translates to:
  /// **'{screens, plural, =1{1 section} other{{screens} sections}} · {permissions} permissions'**
  String settingsAccessSummary(int screens, int permissions);

  /// No description provided for @settingsAccessDefaults.
  ///
  /// In en, this message translates to:
  /// **'defaults'**
  String get settingsAccessDefaults;

  /// No description provided for @settingsRefreshAccess.
  ///
  /// In en, this message translates to:
  /// **'Refresh access'**
  String get settingsRefreshAccess;

  /// No description provided for @settingsRefreshAccessHint.
  ///
  /// In en, this message translates to:
  /// **'Pick up changes made by the academy office'**
  String get settingsRefreshAccessHint;

  /// No description provided for @settingsAccessRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Access refreshed'**
  String get settingsAccessRefreshed;

  /// No description provided for @settingsClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cached data'**
  String get settingsClearCache;

  /// No description provided for @settingsClearCacheHint.
  ///
  /// In en, this message translates to:
  /// **'Keeps anything not yet sent'**
  String get settingsClearCacheHint;

  /// No description provided for @settingsCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cached data cleared'**
  String get settingsCacheCleared;

  /// No description provided for @settingsSections.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get settingsSections;

  /// No description provided for @settingsSwitchRole.
  ///
  /// In en, this message translates to:
  /// **'Switch role'**
  String get settingsSwitchRole;

  /// No description provided for @unsyncedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsynced work'**
  String get unsyncedTitle;

  /// No description provided for @unsyncedAllSent.
  ///
  /// In en, this message translates to:
  /// **'Everything has been sent'**
  String get unsyncedAllSent;

  /// No description provided for @unsyncedWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting to send'**
  String get unsyncedWaiting;

  /// No description provided for @unsyncedRetrying.
  ///
  /// In en, this message translates to:
  /// **'{attempts, plural, =1{Retrying — 1 attempt so far} other{Retrying — {attempts} attempts so far}}'**
  String unsyncedRetrying(int attempts);

  /// No description provided for @unsyncedRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected by the server'**
  String get unsyncedRejected;

  /// No description provided for @attendanceReadOnly.
  ///
  /// In en, this message translates to:
  /// **'You can view this roster but not change it.'**
  String get attendanceReadOnly;

  /// No description provided for @attendanceWillSend.
  ///
  /// In en, this message translates to:
  /// **'Will send when online'**
  String get attendanceWillSend;

  /// No description provided for @attendanceNotMarked.
  ///
  /// In en, this message translates to:
  /// **'Not marked'**
  String get attendanceNotMarked;

  /// No description provided for @attendanceNoStudents.
  ///
  /// In en, this message translates to:
  /// **'No students enrolled in this batch'**
  String get attendanceNoStudents;

  /// No description provided for @attendanceMarkedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{marked} of {total}'**
  String attendanceMarkedOfTotal(int marked, int total);

  /// No description provided for @attendancePresent.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get attendancePresent;

  /// No description provided for @attendanceAbsent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get attendanceAbsent;

  /// No description provided for @attendanceLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get attendanceLate;

  /// No description provided for @attendanceExcused.
  ///
  /// In en, this message translates to:
  /// **'Excused'**
  String get attendanceExcused;

  /// No description provided for @attendanceOnLeave.
  ///
  /// In en, this message translates to:
  /// **'On leave'**
  String get attendanceOnLeave;

  /// No description provided for @roleSuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'System administrator'**
  String get roleSuperAdmin;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Office admin'**
  String get roleAdmin;

  /// No description provided for @roleDeptHead.
  ///
  /// In en, this message translates to:
  /// **'Department head'**
  String get roleDeptHead;

  /// No description provided for @roleTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get roleTeacher;

  /// No description provided for @roleHostelWarden.
  ///
  /// In en, this message translates to:
  /// **'Hostel warden'**
  String get roleHostelWarden;

  /// No description provided for @roleCanteenManager.
  ///
  /// In en, this message translates to:
  /// **'Canteen manager'**
  String get roleCanteenManager;

  /// No description provided for @roleAccountant.
  ///
  /// In en, this message translates to:
  /// **'Accountant'**
  String get roleAccountant;

  /// No description provided for @roleParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get roleParent;

  /// No description provided for @screenToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get screenToday;

  /// No description provided for @screenBatches.
  ///
  /// In en, this message translates to:
  /// **'Batches'**
  String get screenBatches;

  /// No description provided for @screenBatchAttendance.
  ///
  /// In en, this message translates to:
  /// **'Take attendance'**
  String get screenBatchAttendance;

  /// No description provided for @screenBatchHifz.
  ///
  /// In en, this message translates to:
  /// **'Hifz log'**
  String get screenBatchHifz;

  /// No description provided for @screenMarksEntry.
  ///
  /// In en, this message translates to:
  /// **'Marks entry'**
  String get screenMarksEntry;

  /// No description provided for @screenLeaveApprovals.
  ///
  /// In en, this message translates to:
  /// **'Leave approvals'**
  String get screenLeaveApprovals;

  /// No description provided for @screenStudentDetail.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get screenStudentDetail;

  /// No description provided for @screenTeacherReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get screenTeacherReports;

  /// No description provided for @screenWards.
  ///
  /// In en, this message translates to:
  /// **'Wards'**
  String get screenWards;

  /// No description provided for @screenWardAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get screenWardAttendance;

  /// No description provided for @screenWardHifz.
  ///
  /// In en, this message translates to:
  /// **'Hifz'**
  String get screenWardHifz;

  /// No description provided for @screenWardHifzHistory.
  ///
  /// In en, this message translates to:
  /// **'Hifz history'**
  String get screenWardHifzHistory;

  /// No description provided for @screenWardDoura.
  ///
  /// In en, this message translates to:
  /// **'Doura'**
  String get screenWardDoura;

  /// No description provided for @screenWardAcademics.
  ///
  /// In en, this message translates to:
  /// **'Academics'**
  String get screenWardAcademics;

  /// No description provided for @screenWardHomework.
  ///
  /// In en, this message translates to:
  /// **'Homework'**
  String get screenWardHomework;

  /// No description provided for @screenWardResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get screenWardResults;

  /// No description provided for @screenWardActivities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get screenWardActivities;

  /// No description provided for @screenWardLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get screenWardLeave;

  /// No description provided for @screenWardHostel.
  ///
  /// In en, this message translates to:
  /// **'Hostel'**
  String get screenWardHostel;

  /// No description provided for @screenWardCanteen.
  ///
  /// In en, this message translates to:
  /// **'Canteen'**
  String get screenWardCanteen;

  /// No description provided for @screenWardReports.
  ///
  /// In en, this message translates to:
  /// **'Progress reports'**
  String get screenWardReports;

  /// No description provided for @screenNotices.
  ///
  /// In en, this message translates to:
  /// **'Notices'**
  String get screenNotices;

  /// No description provided for @screenRollcall.
  ///
  /// In en, this message translates to:
  /// **'Roll call'**
  String get screenRollcall;

  /// No description provided for @screenGatePass.
  ///
  /// In en, this message translates to:
  /// **'Gate pass'**
  String get screenGatePass;

  /// No description provided for @screenOccupancy.
  ///
  /// In en, this message translates to:
  /// **'Occupancy'**
  String get screenOccupancy;

  /// No description provided for @screenVisitors.
  ///
  /// In en, this message translates to:
  /// **'Visitors'**
  String get screenVisitors;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ml'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return L10nEn();
    case 'ml':
      return L10nMl();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
