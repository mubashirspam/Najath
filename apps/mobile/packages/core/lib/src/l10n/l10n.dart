import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../access/screen_registry.dart';
import '../error/failure.dart';
import 'generated/najath_localizations.dart';

export 'generated/najath_localizations.dart' show L10n;

/// Locales the app ships. Malayalam is first-class from day one, not a later
/// pass — most guardians read it more comfortably than English.
///
/// Arabic is deliberately absent: Quranic content is *rendered* in Arabic by
/// `ArabicText`, but the interface is never in Arabic.
const supportedLocales = <Locale>[Locale('en'), Locale('ml')];

const localizationsDelegates = <LocalizationsDelegate<Object>>[
  L10n.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

extension L10nX on BuildContext {
  /// Localized strings for the active locale.
  ///
  /// Non-nullable: the delegate is installed at the root, so a null here would
  /// mean the app was misconfigured rather than that a string is missing.
  L10n get l10n => L10n.of(this);
}

/// Failure → localized copy.
///
/// The mapping lives here, at the presentation edge. The domain layer carries
/// codes and never a sentence, which is what lets the same failure read
/// correctly in English and Malayalam.
extension FailureL10n on Failure {
  String message(L10n l10n) => switch (this) {
    NetworkFailure() || UnavailableOfflineFailure() => l10n.failureOffline,
    TimeoutFailure() => l10n.failureTimeout,
    UnauthorizedFailure() => l10n.failureSessionEnded,
    ForbiddenFailure() => l10n.failureForbidden,
    ValidationFailure() => l10n.failureValidation,
    ConflictFailure() => l10n.failureConflict,
    NotFoundFailure() => l10n.failureNotFound,
    ServerFailure() => l10n.failureServer,
    UnknownFailure() => l10n.failureUnknown,
  };
}

extension AppRoleL10n on AppRole {
  String label(L10n l10n) => switch (this) {
    AppRole.superAdmin => l10n.roleSuperAdmin,
    AppRole.admin => l10n.roleAdmin,
    AppRole.deptHead => l10n.roleDeptHead,
    AppRole.teacher => l10n.roleTeacher,
    AppRole.hostelWarden => l10n.roleHostelWarden,
    AppRole.canteenManager => l10n.roleCanteenManager,
    AppRole.accountant => l10n.roleAccountant,
    AppRole.parent => l10n.roleParent,
  };
}

/// Screen id → localized nav label.
///
/// The registry's `label` is English and exists for the admin console's matrix,
/// which is an English-only surface. The app must not show it: a guardian's nav
/// bar has to be in their language, and it has to work offline, so the labels
/// ship in the ARB rather than coming from the server.
String screenLabel(L10n l10n, String screenId) => switch (screenId) {
  ScreenId.today => l10n.screenToday,
  ScreenId.batches => l10n.screenBatches,
  ScreenId.batchAttendance => l10n.screenBatchAttendance,
  ScreenId.batchHifz => l10n.screenBatchHifz,
  ScreenId.marksEntry => l10n.screenMarksEntry,
  ScreenId.leaveApprovals => l10n.screenLeaveApprovals,
  ScreenId.studentDetail => l10n.screenStudentDetail,
  ScreenId.teacherReports => l10n.screenTeacherReports,
  ScreenId.wards => l10n.screenWards,
  ScreenId.wardAttendance => l10n.screenWardAttendance,
  ScreenId.wardHifz => l10n.screenWardHifz,
  ScreenId.wardHifzHistory => l10n.screenWardHifzHistory,
  ScreenId.wardDoura => l10n.screenWardDoura,
  ScreenId.wardAcademics => l10n.screenWardAcademics,
  ScreenId.wardHomework => l10n.screenWardHomework,
  ScreenId.wardResults => l10n.screenWardResults,
  ScreenId.wardActivities => l10n.screenWardActivities,
  ScreenId.wardLeave => l10n.screenWardLeave,
  ScreenId.wardHostel => l10n.screenWardHostel,
  ScreenId.wardCanteen => l10n.screenWardCanteen,
  ScreenId.wardReports => l10n.screenWardReports,
  ScreenId.notices => l10n.screenNotices,
  ScreenId.rollcall => l10n.screenRollcall,
  ScreenId.gatePass => l10n.screenGatePass,
  ScreenId.occupancy => l10n.screenOccupancy,
  ScreenId.visitors => l10n.screenVisitors,
  // A screen the server knows about but this build does not. Falling back to
  // the id is ugly on purpose — it should be noticed, not blend in.
  _ => screenId,
};
