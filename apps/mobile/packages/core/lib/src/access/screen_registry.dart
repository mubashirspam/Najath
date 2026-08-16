// GENERATED FILE — DO NOT EDIT.
//
// Emitted from packages/contracts/src/access/ by
//   pnpm --filter @najath/contracts emit:dart
// CI re-runs the emitter and fails if this file is out of date.

import 'permission.dart';

/// Roles a principal can hold. A user may hold several — a DEPT_HEAD is
/// usually also a TEACHER, and a TEACHER may be a PARENT of a student in the
/// same college.
enum AppRole {
  superAdmin('SUPER_ADMIN'),
  admin('ADMIN'),
  deptHead('DEPT_HEAD'),
  teacher('TEACHER'),
  hostelWarden('HOSTEL_WARDEN'),
  canteenManager('CANTEEN_MANAGER'),
  accountant('ACCOUNTANT'),
  parent('PARENT'),
  ;

  const AppRole(this.wire);

  /// The value the API sends, e.g. `SUPER_ADMIN`.
  final String wire;
}

/// Parses a role from the wire, falling back to the least privileged.
AppRole appRoleFromWire(String? wire) {
  return AppRole.values.firstWhere(
    (r) => r.wire == wire,
    orElse: () => AppRole.parent,
  );
}

/// The mobile app is one binary with three shells, resolved from the active
/// role.
enum AppShell {
  teacher,
  parent,
  hostel,
}

AppShell shellForRole(AppRole role) {
  switch (role) {
    case AppRole.superAdmin:
      return AppShell.teacher;
    case AppRole.admin:
      return AppShell.teacher;
    case AppRole.deptHead:
      return AppShell.teacher;
    case AppRole.teacher:
      return AppShell.teacher;
    case AppRole.hostelWarden:
      return AppShell.hostel;
    case AppRole.canteenManager:
      return AppShell.teacher;
    case AppRole.accountant:
      return AppShell.teacher;
    case AppRole.parent:
      return AppShell.parent;
  }
}

/// How far a grant reaches. Mirrors `SCOPE_TYPES`.
enum ScopeType {
  global('GLOBAL'),
  department('DEPARTMENT'),
  assigned('ASSIGNED'),
  hostel('HOSTEL'),
  ward('WARD'),
  self('SELF'),
  none('NONE'),
  ;

  const ScopeType(this.wire);
  final String wire;
}

/// Stable screen identifiers. Stored in the database, never renamed.
class ScreenId {
  ScreenId._();

  static const String today = 'today';
  static const String batches = 'batches';
  static const String batchAttendance = 'batch_attendance';
  static const String batchHifz = 'batch_hifz';
  static const String marksEntry = 'marks_entry';
  static const String leaveApprovals = 'leave_approvals';
  static const String studentDetail = 'student_detail';
  static const String teacherReports = 'teacher_reports';
  static const String wards = 'wards';
  static const String wardAttendance = 'ward_attendance';
  static const String wardHifz = 'ward_hifz';
  static const String wardHifzHistory = 'ward_hifz_history';
  static const String wardDoura = 'ward_doura';
  static const String wardAcademics = 'ward_academics';
  static const String wardHomework = 'ward_homework';
  static const String wardResults = 'ward_results';
  static const String wardActivities = 'ward_activities';
  static const String wardLeave = 'ward_leave';
  static const String wardHostel = 'ward_hostel';
  static const String wardCanteen = 'ward_canteen';
  static const String wardReports = 'ward_reports';
  static const String notices = 'notices';
  static const String rollcall = 'rollcall';
  static const String gatePass = 'gate_pass';
  static const String occupancy = 'occupancy';
  static const String visitors = 'visitors';
}

/// A screen the admin console can grant or revoke per role.
class ScreenDefinition {
  const ScreenDefinition({
    required this.id,
    required this.label,
    required this.shell,
    required this.requires,
    required this.isNavDestination,
    required this.defaultRoles,
  });

  final String id;
  final String label;
  final AppShell shell;

  /// The permission this screen cannot function without.
  final Permission requires;

  final bool isNavDestination;
  final Set<AppRole> defaultRoles;
}

class ScreenRegistry {
  ScreenRegistry._();

  static const List<ScreenDefinition> all = [
    ScreenDefinition(
      id: ScreenId.today,
      label: 'Today',
      shell: AppShell.teacher,
      requires: Permission('timetable', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.superAdmin, AppRole.admin, AppRole.deptHead, AppRole.teacher},
    ),
    ScreenDefinition(
      id: ScreenId.batches,
      label: 'Batches',
      shell: AppShell.teacher,
      requires: Permission('academicStructure', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.superAdmin, AppRole.admin, AppRole.deptHead, AppRole.teacher},
    ),
    ScreenDefinition(
      id: ScreenId.batchAttendance,
      label: 'Take attendance',
      shell: AppShell.teacher,
      requires: Permission('attendance', 'create'),
      isNavDestination: false,
      defaultRoles: {AppRole.superAdmin, AppRole.admin, AppRole.deptHead, AppRole.teacher},
    ),
    ScreenDefinition(
      id: ScreenId.batchHifz,
      label: 'Hifz log',
      shell: AppShell.teacher,
      requires: Permission('hifzLog', 'create'),
      isNavDestination: true,
      defaultRoles: {AppRole.superAdmin, AppRole.admin, AppRole.deptHead, AppRole.teacher},
    ),
    ScreenDefinition(
      id: ScreenId.marksEntry,
      label: 'Marks entry',
      shell: AppShell.teacher,
      requires: Permission('marks', 'create'),
      isNavDestination: false,
      defaultRoles: {AppRole.superAdmin, AppRole.admin, AppRole.deptHead, AppRole.teacher},
    ),
    ScreenDefinition(
      id: ScreenId.leaveApprovals,
      label: 'Leave approvals',
      shell: AppShell.teacher,
      requires: Permission('leave', 'approve'),
      isNavDestination: false,
      defaultRoles: {
        AppRole.superAdmin,
        AppRole.admin,
        AppRole.deptHead,
        AppRole.teacher,
        AppRole.hostelWarden,
      },
    ),
    ScreenDefinition(
      id: ScreenId.studentDetail,
      label: 'Student',
      shell: AppShell.teacher,
      requires: Permission('student', 'read'),
      isNavDestination: false,
      defaultRoles: {AppRole.superAdmin, AppRole.admin, AppRole.deptHead, AppRole.teacher},
    ),
    ScreenDefinition(
      id: ScreenId.teacherReports,
      label: 'Reports',
      shell: AppShell.teacher,
      requires: Permission('report', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.superAdmin, AppRole.admin, AppRole.deptHead, AppRole.teacher},
    ),
    ScreenDefinition(
      id: ScreenId.wards,
      label: 'Wards',
      shell: AppShell.parent,
      requires: Permission('student', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.parent},
    ),
    ScreenDefinition(
      id: ScreenId.wardAttendance,
      label: 'Attendance',
      shell: AppShell.parent,
      requires: Permission('attendance', 'read'),
      isNavDestination: false,
      defaultRoles: {AppRole.parent},
    ),
    ScreenDefinition(
      id: ScreenId.wardHifz,
      label: 'Hifz',
      shell: AppShell.parent,
      requires: Permission('hifzLog', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.parent},
    ),
    ScreenDefinition(
      id: ScreenId.wardHifzHistory,
      label: 'Hifz history',
      shell: AppShell.parent,
      requires: Permission('hifzLog', 'read'),
      isNavDestination: false,
      defaultRoles: {AppRole.parent},
    ),
    ScreenDefinition(
      id: ScreenId.wardDoura,
      label: 'Doura',
      shell: AppShell.parent,
      requires: Permission('doura', 'read'),
      isNavDestination: false,
      defaultRoles: {AppRole.parent},
    ),
    ScreenDefinition(
      id: ScreenId.wardAcademics,
      label: 'Academics',
      shell: AppShell.parent,
      requires: Permission('timetable', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.parent},
    ),
    ScreenDefinition(
      id: ScreenId.wardHomework,
      label: 'Homework',
      shell: AppShell.parent,
      requires: Permission('timetable', 'read'),
      isNavDestination: false,
      defaultRoles: {AppRole.parent},
    ),
    ScreenDefinition(
      id: ScreenId.wardResults,
      label: 'Results',
      shell: AppShell.parent,
      requires: Permission('resultPublish', 'read'),
      isNavDestination: false,
      defaultRoles: {AppRole.parent},
    ),
    ScreenDefinition(
      id: ScreenId.wardActivities,
      label: 'Activities',
      shell: AppShell.parent,
      requires: Permission('activity', 'read'),
      isNavDestination: false,
      defaultRoles: {AppRole.parent},
    ),
    ScreenDefinition(
      id: ScreenId.wardLeave,
      label: 'Leave',
      shell: AppShell.parent,
      requires: Permission('leave', 'create'),
      isNavDestination: true,
      defaultRoles: {AppRole.parent},
    ),
    ScreenDefinition(
      id: ScreenId.wardHostel,
      label: 'Hostel',
      shell: AppShell.parent,
      requires: Permission('hostel', 'read'),
      isNavDestination: false,
      defaultRoles: {AppRole.parent},
    ),
    ScreenDefinition(
      id: ScreenId.wardCanteen,
      label: 'Canteen',
      shell: AppShell.parent,
      requires: Permission('canteen', 'read'),
      isNavDestination: false,
      defaultRoles: {AppRole.parent},
    ),
    ScreenDefinition(
      id: ScreenId.wardReports,
      label: 'Progress reports',
      shell: AppShell.parent,
      requires: Permission('progressReport', 'read'),
      isNavDestination: false,
      defaultRoles: {AppRole.parent},
    ),
    ScreenDefinition(
      id: ScreenId.notices,
      label: 'Notices',
      shell: AppShell.parent,
      requires: Permission('announcement', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.parent},
    ),
    ScreenDefinition(
      id: ScreenId.rollcall,
      label: 'Roll call',
      shell: AppShell.hostel,
      requires: Permission('hostel', 'update'),
      isNavDestination: true,
      defaultRoles: {AppRole.superAdmin, AppRole.admin, AppRole.hostelWarden},
    ),
    ScreenDefinition(
      id: ScreenId.gatePass,
      label: 'Gate pass',
      shell: AppShell.hostel,
      requires: Permission('hostel', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.superAdmin, AppRole.admin, AppRole.hostelWarden},
    ),
    ScreenDefinition(
      id: ScreenId.occupancy,
      label: 'Occupancy',
      shell: AppShell.hostel,
      requires: Permission('hostel', 'read'),
      isNavDestination: true,
      defaultRoles: {AppRole.superAdmin, AppRole.admin, AppRole.hostelWarden},
    ),
    ScreenDefinition(
      id: ScreenId.visitors,
      label: 'Visitors',
      shell: AppShell.hostel,
      requires: Permission('hostel', 'create'),
      isNavDestination: false,
      defaultRoles: {AppRole.superAdmin, AppRole.admin, AppRole.hostelWarden},
    ),
  ];

  static ScreenDefinition? byId(String id) {
    for (final screen in all) {
      if (screen.id == id) return screen;
    }
    return null;
  }

  /// Screens belonging to one shell, in declaration order.
  static List<ScreenDefinition> forShell(AppShell shell) =>
      all.where((s) => s.shell == shell).toList();

  /// Top-level tabs of one shell.
  static List<ScreenDefinition> navDestinations(AppShell shell) =>
      all.where((s) => s.shell == shell && s.isNavDestination).toList();

  /// Screens a role holds before any admin customisation. The fallback when
  /// the app has never managed to fetch a policy.
  static Set<String> defaultScreensFor(AppRole role) => {
    for (final screen in all)
      if (screen.defaultRoles.contains(role)) screen.id,
  };
}

/// Every resource the API recognises, and the actions it supports.
class Resources {
  Resources._();

  static const String user = 'user';
  static const List<String> userActions = ['create', 'read', 'update', 'delete'];
  static const String student = 'student';
  static const List<String> studentActions = ['create', 'read', 'update', 'delete'];
  static const String staff = 'staff';
  static const List<String> staffActions = ['create', 'read', 'update', 'delete'];
  static const String academicStructure = 'academicStructure';
  static const List<String> academicStructureActions = ['create', 'read', 'update', 'delete'];
  static const String timetable = 'timetable';
  static const List<String> timetableActions = ['create', 'read', 'update', 'delete'];
  static const String attendance = 'attendance';
  static const List<String> attendanceActions = ['create', 'read', 'update', 'delete'];
  static const String hifzLog = 'hifzLog';
  static const List<String> hifzLogActions = ['create', 'read', 'update', 'delete'];
  static const String doura = 'doura';
  static const List<String> douraActions = ['create', 'read', 'update', 'delete'];
  static const String exam = 'exam';
  static const List<String> examActions = ['create', 'read', 'update', 'delete'];
  static const String marks = 'marks';
  static const List<String> marksActions = ['create', 'read', 'update', 'approve'];
  static const String resultPublish = 'resultPublish';
  static const List<String> resultPublishActions = ['read', 'approve'];
  static const String progressReport = 'progressReport';
  static const List<String> progressReportActions = [
    'create',
    'read',
    'update',
    'delete',
    'approve',
  ];
  static const String activity = 'activity';
  static const List<String> activityActions = ['create', 'read', 'update', 'delete'];
  static const String leave = 'leave';
  static const List<String> leaveActions = ['create', 'read', 'update', 'delete', 'approve'];
  static const String hostel = 'hostel';
  static const List<String> hostelActions = ['create', 'read', 'update', 'delete'];
  static const String canteen = 'canteen';
  static const List<String> canteenActions = ['create', 'read', 'update', 'delete'];
  static const String announcement = 'announcement';
  static const List<String> announcementActions = ['create', 'read', 'update', 'delete'];
  static const String report = 'report';
  static const List<String> reportActions = ['read'];

  static const Map<String, List<String>> all = {
    user: userActions,
    student: studentActions,
    staff: staffActions,
    academicStructure: academicStructureActions,
    timetable: timetableActions,
    attendance: attendanceActions,
    hifzLog: hifzLogActions,
    doura: douraActions,
    exam: examActions,
    marks: marksActions,
    resultPublish: resultPublishActions,
    progressReport: progressReportActions,
    activity: activityActions,
    leave: leaveActions,
    hostel: hostelActions,
    canteen: canteenActions,
    announcement: announcementActions,
    report: reportActions,
  };
}
