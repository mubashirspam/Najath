import type { Permission, Role } from './roles';

/**
 * The mobile app is one binary with three shells, resolved from the signed-in
 * user's active role (spec §7.2). The console is not a shell — it is a separate
 * client.
 */
export const SHELLS = ['teacher', 'parent', 'hostel'] as const;
export type Shell = (typeof SHELLS)[number];

export interface ScreenDefinition {
  /** Stable id, stored in the database. Never renamed once shipped. */
  readonly id: string;
  readonly label: string;
  readonly shell: Shell;
  /**
   * The permission this screen cannot function without. The admin console can
   * revoke a screen from a role that holds the permission; it cannot grant one
   * to a role that does not, because every request the screen makes would 403.
   */
  readonly requires: Permission;
  /** A top-level tab in its shell, as opposed to a screen you navigate into. */
  readonly isNavDestination: boolean;
  readonly defaultRoles: readonly Role[];
}

const STAFF_ACADEMIC: readonly Role[] = ['SUPER_ADMIN', 'ADMIN', 'DEPT_HEAD', 'TEACHER'];

export const SCREENS = [
  // ── Teacher shell — spec §7.7 ──────────────────────────────────────────────
  {
    id: 'today',
    label: 'Today',
    shell: 'teacher',
    requires: 'timetable:read',
    isNavDestination: true,
    defaultRoles: STAFF_ACADEMIC,
  },
  {
    id: 'batches',
    label: 'Batches',
    shell: 'teacher',
    requires: 'academicStructure:read',
    isNavDestination: true,
    defaultRoles: STAFF_ACADEMIC,
  },
  {
    id: 'batch_attendance',
    label: 'Take attendance',
    shell: 'teacher',
    requires: 'attendance:create',
    isNavDestination: false,
    defaultRoles: STAFF_ACADEMIC,
  },
  {
    id: 'batch_hifz',
    label: 'Hifz log',
    shell: 'teacher',
    requires: 'hifzLog:create',
    isNavDestination: true,
    defaultRoles: STAFF_ACADEMIC,
  },
  {
    id: 'marks_entry',
    label: 'Marks entry',
    shell: 'teacher',
    requires: 'marks:create',
    isNavDestination: false,
    defaultRoles: STAFF_ACADEMIC,
  },
  {
    id: 'leave_approvals',
    label: 'Leave approvals',
    shell: 'teacher',
    requires: 'leave:approve',
    isNavDestination: false,
    defaultRoles: ['SUPER_ADMIN', 'ADMIN', 'DEPT_HEAD', 'TEACHER', 'HOSTEL_WARDEN'],
  },
  {
    id: 'student_detail',
    label: 'Student',
    shell: 'teacher',
    requires: 'student:read',
    isNavDestination: false,
    defaultRoles: STAFF_ACADEMIC,
  },
  {
    id: 'teacher_reports',
    label: 'Reports',
    shell: 'teacher',
    requires: 'report:read',
    isNavDestination: true,
    defaultRoles: STAFF_ACADEMIC,
  },

  // ── Parent shell — ward-scoped, spec §7.7 ─────────────────────────────────
  {
    id: 'wards',
    label: 'Wards',
    shell: 'parent',
    requires: 'student:read',
    isNavDestination: true,
    defaultRoles: ['PARENT'],
  },
  {
    id: 'ward_attendance',
    label: 'Attendance',
    shell: 'parent',
    requires: 'attendance:read',
    isNavDestination: false,
    defaultRoles: ['PARENT'],
  },
  {
    id: 'ward_hifz',
    label: 'Hifz',
    shell: 'parent',
    requires: 'hifzLog:read',
    isNavDestination: true,
    defaultRoles: ['PARENT'],
  },
  {
    id: 'ward_hifz_history',
    label: 'Hifz history',
    shell: 'parent',
    requires: 'hifzLog:read',
    isNavDestination: false,
    defaultRoles: ['PARENT'],
  },
  {
    id: 'ward_doura',
    label: 'Doura',
    shell: 'parent',
    requires: 'doura:read',
    isNavDestination: false,
    defaultRoles: ['PARENT'],
  },
  {
    id: 'ward_academics',
    label: 'Academics',
    shell: 'parent',
    requires: 'timetable:read',
    isNavDestination: true,
    defaultRoles: ['PARENT'],
  },
  {
    id: 'ward_homework',
    label: 'Homework',
    shell: 'parent',
    requires: 'timetable:read',
    isNavDestination: false,
    defaultRoles: ['PARENT'],
  },
  {
    id: 'ward_results',
    label: 'Results',
    shell: 'parent',
    requires: 'resultPublish:read',
    isNavDestination: false,
    defaultRoles: ['PARENT'],
  },
  {
    id: 'ward_activities',
    label: 'Activities',
    shell: 'parent',
    requires: 'activity:read',
    isNavDestination: false,
    defaultRoles: ['PARENT'],
  },
  {
    id: 'ward_leave',
    label: 'Leave',
    shell: 'parent',
    requires: 'leave:create',
    isNavDestination: true,
    defaultRoles: ['PARENT'],
  },
  {
    id: 'ward_hostel',
    label: 'Hostel',
    shell: 'parent',
    requires: 'hostel:read',
    isNavDestination: false,
    defaultRoles: ['PARENT'],
  },
  {
    id: 'ward_canteen',
    label: 'Canteen',
    shell: 'parent',
    requires: 'canteen:read',
    isNavDestination: false,
    defaultRoles: ['PARENT'],
  },
  {
    id: 'ward_reports',
    label: 'Progress reports',
    shell: 'parent',
    requires: 'progressReport:read',
    isNavDestination: false,
    defaultRoles: ['PARENT'],
  },
  {
    id: 'notices',
    label: 'Notices',
    shell: 'parent',
    requires: 'announcement:read',
    isNavDestination: true,
    defaultRoles: ['PARENT'],
  },

  // ── Hostel shell ──────────────────────────────────────────────────────────
  {
    id: 'rollcall',
    label: 'Roll call',
    shell: 'hostel',
    requires: 'hostel:update',
    isNavDestination: true,
    defaultRoles: ['SUPER_ADMIN', 'ADMIN', 'HOSTEL_WARDEN'],
  },
  {
    id: 'gate_pass',
    label: 'Gate pass',
    shell: 'hostel',
    requires: 'hostel:read',
    isNavDestination: true,
    defaultRoles: ['SUPER_ADMIN', 'ADMIN', 'HOSTEL_WARDEN'],
  },
  {
    id: 'occupancy',
    label: 'Occupancy',
    shell: 'hostel',
    requires: 'hostel:read',
    isNavDestination: true,
    defaultRoles: ['SUPER_ADMIN', 'ADMIN', 'HOSTEL_WARDEN'],
  },
  {
    id: 'visitors',
    label: 'Visitors',
    shell: 'hostel',
    requires: 'hostel:create',
    isNavDestination: false,
    defaultRoles: ['SUPER_ADMIN', 'ADMIN', 'HOSTEL_WARDEN'],
  },
] as const satisfies readonly ScreenDefinition[];

export type ScreenId = (typeof SCREENS)[number]['id'];

export const SCREEN_IDS = SCREENS.map((s) => s.id) as readonly ScreenId[];

export function screenById(id: string): ScreenDefinition | undefined {
  return SCREENS.find((s) => s.id === id);
}

export function screensForShell(shell: Shell): readonly ScreenDefinition[] {
  return SCREENS.filter((s) => s.shell === shell);
}

/** The screens a role gets before any admin customisation. */
export function defaultScreensForRole(role: Role): readonly ScreenId[] {
  return SCREENS.filter((s) => (s.defaultRoles as readonly Role[]).includes(role)).map((s) => s.id);
}

/**
 * The shell a role resolves to. A user holding several roles picks one in the
 * role switcher; this is the default for each.
 */
export function shellForRole(role: Role): Shell {
  if (role === 'PARENT') return 'parent';
  if (role === 'HOSTEL_WARDEN') return 'hostel';
  return 'teacher';
}
