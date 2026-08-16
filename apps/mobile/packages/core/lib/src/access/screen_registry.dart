// GENERATED FILE — DO NOT EDIT.
//
// Emitted from packages/contracts/src/access.ts by
//   pnpm --filter @najath/contracts emit:dart
// CI re-runs the emitter and fails if this file is out of date.

import 'permission.dart';

/// Roles a principal can hold. Mirrors `ROLES` in the contracts package.
enum AppRole {
  admin,
  staff,
  teacher,
  guardian,
}

/// Parses a role name from the wire, falling back to the least privileged.
AppRole appRoleFromName(String? name) {
  return AppRole.values.firstWhere(
    (r) => r.name == name,
    orElse: () => AppRole.guardian,
  );
}

/// Stable screen identifiers. These strings are stored in the database, so
/// they are never renamed once shipped.
class ScreenId {
  ScreenId._();

  static const String dashboard = 'dashboard';
  static const String attendance = 'attendance';
  static const String attendanceMark = 'attendance_mark';
  static const String hifz = 'hifz';
  static const String hifzRecord = 'hifz_record';
  static const String academics = 'academics';
  static const String exams = 'exams';
  static const String examGrading = 'exam_grading';
  static const String progress = 'progress';
  static const String leave = 'leave';
  static const String leaveApproval = 'leave_approval';
  static const String hostel = 'hostel';
  static const String canteen = 'canteen';
  static const String activities = 'activities';
  static const String announcements = 'announcements';
  static const String profile = 'profile';
}

/// A screen the admin console can grant or revoke per role.
class ScreenDefinition {
  const ScreenDefinition({
    required this.id,
    required this.label,
    required this.requires,
    required this.isNavDestination,
    required this.defaultRoles,
  });

  final String id;
  final String label;

  /// The permission this screen cannot function without.
  final Permission requires;

  final bool isNavDestination;
  final Set<AppRole> defaultRoles;
}

class ScreenRegistry {
  ScreenRegistry._();

  static const List<ScreenDefinition> all = [
    ScreenDefinition(
      id: ScreenId.dashboard,
      label: 'Dashboard',
      requires: Permission('announcement', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.admin, AppRole.staff, AppRole.teacher, AppRole.guardian},
    ),
    ScreenDefinition(
      id: ScreenId.attendance,
      label: 'Attendance',
      requires: Permission('attendance', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.admin, AppRole.staff, AppRole.teacher, AppRole.guardian},
    ),
    ScreenDefinition(
      id: ScreenId.attendanceMark,
      label: 'Mark attendance',
      requires: Permission('attendance', 'mark'),
      isNavDestination: false,
      defaultRoles: {AppRole.admin, AppRole.staff, AppRole.teacher},
    ),
    ScreenDefinition(
      id: ScreenId.hifz,
      label: 'Hifz',
      requires: Permission('hifz', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.admin, AppRole.staff, AppRole.teacher, AppRole.guardian},
    ),
    ScreenDefinition(
      id: ScreenId.hifzRecord,
      label: 'Record hifz',
      requires: Permission('hifz', 'record'),
      isNavDestination: false,
      defaultRoles: {AppRole.admin, AppRole.staff, AppRole.teacher},
    ),
    ScreenDefinition(
      id: ScreenId.academics,
      label: 'Classes & students',
      requires: Permission('student', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.admin, AppRole.staff, AppRole.teacher},
    ),
    ScreenDefinition(
      id: ScreenId.exams,
      label: 'Exams',
      requires: Permission('exam', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.admin, AppRole.staff, AppRole.teacher, AppRole.guardian},
    ),
    ScreenDefinition(
      id: ScreenId.examGrading,
      label: 'Grading',
      requires: Permission('exam', 'grade'),
      isNavDestination: false,
      defaultRoles: {AppRole.admin, AppRole.staff, AppRole.teacher},
    ),
    ScreenDefinition(
      id: ScreenId.progress,
      label: 'Progress',
      requires: Permission('report', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.admin, AppRole.staff, AppRole.teacher, AppRole.guardian},
    ),
    ScreenDefinition(
      id: ScreenId.leave,
      label: 'Leave',
      requires: Permission('leave', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.admin, AppRole.staff, AppRole.teacher, AppRole.guardian},
    ),
    ScreenDefinition(
      id: ScreenId.leaveApproval,
      label: 'Approve leave',
      requires: Permission('leave', 'approve'),
      isNavDestination: false,
      defaultRoles: {AppRole.admin, AppRole.staff},
    ),
    ScreenDefinition(
      id: ScreenId.hostel,
      label: 'Hostel',
      requires: Permission('hostel', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.admin, AppRole.staff, AppRole.guardian},
    ),
    ScreenDefinition(
      id: ScreenId.canteen,
      label: 'Canteen',
      requires: Permission('canteen', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.admin, AppRole.staff, AppRole.guardian},
    ),
    ScreenDefinition(
      id: ScreenId.activities,
      label: 'Activities',
      requires: Permission('announcement', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.admin, AppRole.staff, AppRole.teacher, AppRole.guardian},
    ),
    ScreenDefinition(
      id: ScreenId.announcements,
      label: 'Announcements',
      requires: Permission('announcement', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.admin, AppRole.staff, AppRole.teacher, AppRole.guardian},
    ),
    ScreenDefinition(
      id: ScreenId.profile,
      label: 'Profile',
      requires: Permission('announcement', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.admin, AppRole.staff, AppRole.teacher, AppRole.guardian},
    ),
  ];

  /// Top-level navigation destinations, in the order they should appear.
  static List<ScreenDefinition> get navDestinations =>
      all.where((s) => s.isNavDestination).toList();

  static ScreenDefinition? byId(String id) {
    for (final screen in all) {
      if (screen.id == id) return screen;
    }
    return null;
  }

  /// Screens a role holds before any admin customisation. Used as the
  /// fallback when the app has never managed to fetch a policy.
  static Set<String> defaultScreensFor(AppRole role) => {
    for (final screen in all)
      if (screen.defaultRoles.contains(role)) screen.id,
  };
}

/// Every `resource:action` pair the API recognises.
class Resources {
  Resources._();

  static const String student = 'student';
  static const List<String> studentActions = ['create', 'read', 'update', 'delete'];
  static const String attendance = 'attendance';
  static const List<String> attendanceActions = ['read', 'mark', 'amend'];
  static const String hifz = 'hifz';
  static const List<String> hifzActions = ['read', 'record', 'verify'];
  static const String exam = 'exam';
  static const List<String> examActions = ['read', 'create', 'grade', 'publish'];
  static const String leave = 'leave';
  static const List<String> leaveActions = ['read', 'request', 'approve'];
  static const String hostel = 'hostel';
  static const List<String> hostelActions = ['read', 'manage'];
  static const String canteen = 'canteen';
  static const List<String> canteenActions = ['read', 'manage'];
  static const String announcement = 'announcement';
  static const List<String> announcementActions = ['read', 'publish'];
  static const String report = 'report';
  static const List<String> reportActions = ['read', 'export'];

  static const Map<String, List<String>> all = {
    student: studentActions,
    attendance: attendanceActions,
    hifz: hifzActions,
    exam: examActions,
    leave: leaveActions,
    hostel: hostelActions,
    canteen: canteenActions,
    announcement: announcementActions,
    report: reportActions,
  };
}
