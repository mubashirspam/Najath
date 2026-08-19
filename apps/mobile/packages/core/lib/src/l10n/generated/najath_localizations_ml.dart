// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'najath_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malayalam (`ml`).
class L10nMl extends L10n {
  L10nMl([String locale = 'ml']) : super(locale);

  @override
  String get appName => 'നജാത്ത്';

  @override
  String get appTagline => 'ഖുർആൻ അക്കാദമി';

  @override
  String get actionTryAgain => 'വീണ്ടും ശ്രമിക്കുക';

  @override
  String get actionGoBack => 'തിരികെ പോകുക';

  @override
  String get actionSignIn => 'സൈൻ ഇൻ';

  @override
  String get actionSignOut => 'സൈൻ ഔട്ട്';

  @override
  String get actionSendCode => 'കോഡ് അയയ്ക്കുക';

  @override
  String get actionVerifyCode => 'കോഡ് പരിശോധിക്കുക';

  @override
  String get actionResendCode => 'കോഡ് വീണ്ടും അയയ്ക്കുക';

  @override
  String get actionDiscard => 'ഒഴിവാക്കുക';

  @override
  String get actionTryNow => 'ഇപ്പോൾ ശ്രമിക്കുക';

  @override
  String get failureOffline => 'ഓഫ്‌ലൈനിൽ ഇത് ഇനിയും ലഭ്യമല്ല';

  @override
  String get failureTimeout => 'സെർവർ പ്രതികരിക്കാൻ വളരെ സമയമെടുത്തു';

  @override
  String get failureSessionEnded => 'നിങ്ങളുടെ സെഷൻ അവസാനിച്ചു';

  @override
  String get failureForbidden => 'ഇതിലേക്ക് നിങ്ങൾക്ക് പ്രവേശനമില്ല';

  @override
  String get failureValidation => 'ചില വിവരങ്ങൾ തിരുത്തേണ്ടതുണ്ട്';

  @override
  String get failureConflict => 'ഇത് മറ്റൊരിടത്ത് മാറ്റിയിട്ടുണ്ട്';

  @override
  String get failureNotFound => 'കണ്ടെത്തിയില്ല';

  @override
  String get failureServer => 'ഞങ്ങളുടെ ഭാഗത്ത് എന്തോ പിഴവ് സംഭവിച്ചു';

  @override
  String get failureUnknown => 'എന്തോ പിഴവ് സംഭവിച്ചു';

  @override
  String get failureOfflineHint => 'വീണ്ടും ഓൺലൈനാകുമ്പോൾ ഇത് ലോഡ് ചെയ്യും.';

  @override
  String get offlineShowingSaved => 'ഓഫ്‌ലൈൻ — സേവ് ചെയ്ത വിവരങ്ങൾ കാണിക്കുന്നു';

  @override
  String offlinePendingWrites(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ഓഫ്‌ലൈൻ — $count മാറ്റങ്ങൾ കണക്ഷൻ ലഭിക്കുമ്പോൾ അയയ്ക്കും',
      one: 'ഓഫ്‌ലൈൻ — 1 മാറ്റം കണക്ഷൻ ലഭിക്കുമ്പോൾ അയയ്ക്കും',
    );
    return '$_temp0';
  }

  @override
  String get syncSending => 'നിങ്ങളുടെ മാറ്റങ്ങൾ അയയ്ക്കുന്നു…';

  @override
  String syncSendingItem(String label) {
    return '$label അയയ്ക്കുന്നു…';
  }

  @override
  String get syncUpdating => 'പുതുക്കുന്നു…';

  @override
  String syncUpdatingItem(String label) {
    return '$label പുതുക്കുന്നു…';
  }

  @override
  String get syncUpToDate => 'എല്ലാം പുതുക്കിയിട്ടുണ്ട്';

  @override
  String get syncCouldNotFinish => 'സിങ്ക് പൂർത്തിയാക്കാനായില്ല';

  @override
  String get syncFallbackPolicy =>
      'സ്ഥിരം പ്രവേശനം കാണിക്കുന്നു — അക്കാദമി ക്രമീകരണങ്ങൾ ലഭിക്കാൻ ഒരിക്കൽ കണക്റ്റ് ചെയ്യുക.';

  @override
  String get noAccessTitle => 'പ്രവേശനമില്ല';

  @override
  String noAccessBody(String section) {
    return '$section എന്നതിലേക്ക് നിങ്ങൾക്ക് പ്രവേശനമില്ല';
  }

  @override
  String get noAccessSectionFallback => 'ഈ വിഭാഗം';

  @override
  String get noAccessHint =>
      'പ്രവേശനം അക്കാദമി ഓഫീസാണ് നിയന്ത്രിക്കുന്നത്. ആവശ്യമെങ്കിൽ നിങ്ങളുടെ റോളിന് ഇത് അനുവദിക്കാൻ അവരോട് ആവശ്യപ്പെടുക.';

  @override
  String get noSectionsEnabled =>
      'നിങ്ങളുടെ അക്കൗണ്ടിന് ഇതുവരെ ഒരു വിഭാഗവും അനുവദിച്ചിട്ടില്ല.\nഅക്കാദമി ഓഫീസിന് നിങ്ങളുടെ റോളിന് അവ അനുവദിക്കാം.';

  @override
  String get loginStaffTab => 'സ്റ്റാഫ്';

  @override
  String get loginParentTab => 'രക്ഷിതാവ്';

  @override
  String get loginEmail => 'ഇമെയിൽ';

  @override
  String get loginPassword => 'പാസ്‌വേഡ്';

  @override
  String get loginPhone => 'ഫോൺ നമ്പർ';

  @override
  String get loginOtpCode => 'ആറക്ക കോഡ്';

  @override
  String get loginRememberMe => 'എന്നെ ഓർത്തിരിക്കുക';

  @override
  String get loginEnterEmail => 'നിങ്ങളുടെ ഇമെയിൽ നൽകുക';

  @override
  String get loginEnterPhone => 'നിങ്ങളുടെ ഫോൺ നമ്പർ നൽകുക';

  @override
  String get loginEnterPassword => 'നിങ്ങളുടെ പാസ്‌വേഡ് നൽകുക';

  @override
  String get loginEnterCode => 'ഞങ്ങൾ അയച്ച കോഡ് നൽകുക';

  @override
  String get loginInvalidEmail => 'ഇത് ഒരു ഇമെയിൽ പോലെ തോന്നുന്നില്ല';

  @override
  String get settingsTitle => 'ക്രമീകരണങ്ങൾ';

  @override
  String get settingsAppearance => 'കാഴ്ച';

  @override
  String get settingsYourAccess => 'നിങ്ങളുടെ പ്രവേശനം';

  @override
  String settingsAccessSummary(int screens, int permissions) {
    String _temp0 = intl.Intl.pluralLogic(
      screens,
      locale: localeName,
      other: '$screens വിഭാഗങ്ങൾ',
      one: '1 വിഭാഗം',
    );
    return '$_temp0 · $permissions അനുമതികൾ';
  }

  @override
  String get settingsAccessDefaults => 'സ്ഥിരം';

  @override
  String get settingsRefreshAccess => 'പ്രവേശനം പുതുക്കുക';

  @override
  String get settingsRefreshAccessHint => 'അക്കാദമി ഓഫീസ് വരുത്തിയ മാറ്റങ്ങൾ എടുക്കുക';

  @override
  String get settingsAccessRefreshed => 'പ്രവേശനം പുതുക്കി';

  @override
  String get settingsClearCache => 'സേവ് ചെയ്ത വിവരങ്ങൾ മായ്ക്കുക';

  @override
  String get settingsClearCacheHint => 'അയയ്ക്കാൻ ബാക്കിയുള്ളവ നിലനിർത്തും';

  @override
  String get settingsCacheCleared => 'സേവ് ചെയ്ത വിവരങ്ങൾ മായ്ച്ചു';

  @override
  String get settingsSections => 'വിഭാഗങ്ങൾ';

  @override
  String get settingsSwitchRole => 'റോൾ മാറ്റുക';

  @override
  String get unsyncedTitle => 'അയയ്ക്കാത്ത ജോലി';

  @override
  String get unsyncedAllSent => 'എല്ലാം അയച്ചു കഴിഞ്ഞു';

  @override
  String get unsyncedWaiting => 'അയയ്ക്കാൻ കാത്തിരിക്കുന്നു';

  @override
  String unsyncedRetrying(int attempts) {
    String _temp0 = intl.Intl.pluralLogic(
      attempts,
      locale: localeName,
      other: 'വീണ്ടും ശ്രമിക്കുന്നു — ഇതുവരെ $attempts ശ്രമങ്ങൾ',
      one: 'വീണ്ടും ശ്രമിക്കുന്നു — ഇതുവരെ 1 ശ്രമം',
    );
    return '$_temp0';
  }

  @override
  String get unsyncedRejected => 'സെർവർ നിരസിച്ചു';

  @override
  String get attendanceReadOnly => 'ഈ പട്ടിക കാണാം, മാറ്റാൻ കഴിയില്ല.';

  @override
  String get attendanceWillSend => 'ഓൺലൈനാകുമ്പോൾ അയയ്ക്കും';

  @override
  String get attendanceNotMarked => 'രേഖപ്പെടുത്തിയിട്ടില്ല';

  @override
  String get attendanceNoStudents => 'ഈ ബാച്ചിൽ വിദ്യാർഥികളില്ല';

  @override
  String attendanceMarkedOfTotal(int marked, int total) {
    return '$total-ൽ $marked';
  }

  @override
  String get attendancePresent => 'ഹാജർ';

  @override
  String get attendanceAbsent => 'ഹാജരില്ല';

  @override
  String get attendanceLate => 'വൈകി';

  @override
  String get attendanceExcused => 'ഇളവ്';

  @override
  String get attendanceOnLeave => 'അവധിയിൽ';

  @override
  String get roleSuperAdmin => 'സിസ്റ്റം അഡ്മിനിസ്‌ട്രേറ്റർ';

  @override
  String get roleAdmin => 'ഓഫീസ് അഡ്മിൻ';

  @override
  String get roleDeptHead => 'ഡിപ്പാർട്ട്‌മെന്റ് മേധാവി';

  @override
  String get roleTeacher => 'അധ്യാപകൻ';

  @override
  String get roleHostelWarden => 'ഹോസ്റ്റൽ വാർഡൻ';

  @override
  String get roleCanteenManager => 'കാന്റീൻ മാനേജർ';

  @override
  String get roleAccountant => 'അക്കൗണ്ടന്റ്';

  @override
  String get roleParent => 'രക്ഷിതാവ്';

  @override
  String get screenToday => 'ഇന്ന്';

  @override
  String get screenBatches => 'ബാച്ചുകൾ';

  @override
  String get screenBatchAttendance => 'ഹാജർ രേഖപ്പെടുത്തുക';

  @override
  String get screenBatchHifz => 'ഹിഫ്‌സ് രേഖ';

  @override
  String get screenMarksEntry => 'മാർക്ക് രേഖപ്പെടുത്തൽ';

  @override
  String get screenLeaveApprovals => 'അവധി അനുമതികൾ';

  @override
  String get screenStudentDetail => 'വിദ്യാർഥി';

  @override
  String get screenTeacherReports => 'റിപ്പോർട്ടുകൾ';

  @override
  String get screenWards => 'കുട്ടികൾ';

  @override
  String get screenWardAttendance => 'ഹാജർ';

  @override
  String get screenWardHifz => 'ഹിഫ്‌സ്';

  @override
  String get screenWardHifzHistory => 'ഹിഫ്‌സ് ചരിത്രം';

  @override
  String get screenWardDoura => 'ദൗറ';

  @override
  String get screenWardAcademics => 'പഠനം';

  @override
  String get screenWardHomework => 'ഗൃഹപാഠം';

  @override
  String get screenWardResults => 'ഫലങ്ങൾ';

  @override
  String get screenWardActivities => 'പ്രവർത്തനങ്ങൾ';

  @override
  String get screenWardLeave => 'അവധി';

  @override
  String get screenWardHostel => 'ഹോസ്റ്റൽ';

  @override
  String get screenWardCanteen => 'കാന്റീൻ';

  @override
  String get screenWardReports => 'പുരോഗതി റിപ്പോർട്ടുകൾ';

  @override
  String get screenNotices => 'അറിയിപ്പുകൾ';

  @override
  String get screenRollcall => 'റോൾ കോൾ';

  @override
  String get screenGatePass => 'ഗേറ്റ് പാസ്';

  @override
  String get screenOccupancy => 'താമസ വിവരം';

  @override
  String get screenVisitors => 'സന്ദർശകർ';
}
