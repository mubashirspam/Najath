/**
 * The canonical access-control registry.
 *
 * This file is the single source of truth for three consumers:
 *
 *   1. the admin console, which renders the role → screen matrix,
 *   2. the API, which resolves a principal's effective policy,
 *   3. the Flutter app, whose Dart mirror is emitted from here by
 *      `pnpm --filter @najath/contracts emit:dart` and checked in CI.
 *
 * Adding a screen means adding it here and re-running the emitter. Never edit
 * the Dart file by hand.
 */

export const ROLES = ['admin', 'staff', 'teacher', 'guardian'] as const;
export type Role = (typeof ROLES)[number];

/** Resource → the actions that can be performed on it. */
export const RESOURCES = {
  student: ['create', 'read', 'update', 'delete'],
  attendance: ['read', 'mark', 'amend'],
  hifz: ['read', 'record', 'verify'],
  exam: ['read', 'create', 'grade', 'publish'],
  leave: ['read', 'request', 'approve'],
  hostel: ['read', 'manage'],
  canteen: ['read', 'manage'],
  announcement: ['read', 'publish'],
  report: ['read', 'export'],
} as const satisfies Record<string, readonly string[]>;

export type Resource = keyof typeof RESOURCES;
export type Action<R extends Resource = Resource> = (typeof RESOURCES)[R][number];

/** `resource:action`, the wire form of a single permission. */
export type Permission = {
  [R in Resource]: `${R}:${(typeof RESOURCES)[R][number]}`;
}[Resource];

export interface ScreenDefinition {
  /** Stable id. Stored in the database; never renamed once shipped. */
  readonly id: string;
  /** Label shown in the admin console's access matrix. */
  readonly label: string;
  /**
   * Permission a role must hold for this screen to be reachable at all.
   * The admin console can revoke a screen from a role that holds the
   * permission, but it cannot grant a screen to a role that does not — the API
   * would reject every request the screen makes.
   */
  readonly requires: Permission;
  /** Whether the screen is a top-level destination in the mobile app's nav. */
  readonly isNavDestination: boolean;
  /** Roles that get this screen when the academy has not customised anything. */
  readonly defaultRoles: readonly Role[];
}

export const SCREENS = [
  {
    id: 'dashboard',
    label: 'Dashboard',
    requires: 'announcement:read',
    isNavDestination: true,
    defaultRoles: ['admin', 'staff', 'teacher', 'guardian'],
  },
  {
    id: 'attendance',
    label: 'Attendance',
    requires: 'attendance:read',
    isNavDestination: true,
    defaultRoles: ['admin', 'staff', 'teacher', 'guardian'],
  },
  {
    id: 'attendance_mark',
    label: 'Mark attendance',
    requires: 'attendance:mark',
    isNavDestination: false,
    defaultRoles: ['admin', 'staff', 'teacher'],
  },
  {
    id: 'hifz',
    label: 'Hifz',
    requires: 'hifz:read',
    isNavDestination: true,
    defaultRoles: ['admin', 'staff', 'teacher', 'guardian'],
  },
  {
    id: 'hifz_record',
    label: 'Record hifz',
    requires: 'hifz:record',
    isNavDestination: false,
    defaultRoles: ['admin', 'staff', 'teacher'],
  },
  {
    id: 'academics',
    label: 'Classes & students',
    requires: 'student:read',
    isNavDestination: true,
    defaultRoles: ['admin', 'staff', 'teacher'],
  },
  {
    id: 'exams',
    label: 'Exams',
    requires: 'exam:read',
    isNavDestination: true,
    defaultRoles: ['admin', 'staff', 'teacher', 'guardian'],
  },
  {
    id: 'exam_grading',
    label: 'Grading',
    requires: 'exam:grade',
    isNavDestination: false,
    defaultRoles: ['admin', 'staff', 'teacher'],
  },
  {
    id: 'progress',
    label: 'Progress',
    requires: 'report:read',
    isNavDestination: true,
    defaultRoles: ['admin', 'staff', 'teacher', 'guardian'],
  },
  {
    id: 'leave',
    label: 'Leave',
    requires: 'leave:read',
    isNavDestination: true,
    defaultRoles: ['admin', 'staff', 'teacher', 'guardian'],
  },
  {
    id: 'leave_approval',
    label: 'Approve leave',
    requires: 'leave:approve',
    isNavDestination: false,
    defaultRoles: ['admin', 'staff'],
  },
  {
    id: 'hostel',
    label: 'Hostel',
    requires: 'hostel:read',
    isNavDestination: true,
    defaultRoles: ['admin', 'staff', 'guardian'],
  },
  {
    id: 'canteen',
    label: 'Canteen',
    requires: 'canteen:read',
    isNavDestination: true,
    defaultRoles: ['admin', 'staff', 'guardian'],
  },
  {
    id: 'activities',
    label: 'Activities',
    requires: 'announcement:read',
    isNavDestination: true,
    defaultRoles: ['admin', 'staff', 'teacher', 'guardian'],
  },
  {
    id: 'announcements',
    label: 'Announcements',
    requires: 'announcement:read',
    isNavDestination: true,
    defaultRoles: ['admin', 'staff', 'teacher', 'guardian'],
  },
  {
    id: 'profile',
    label: 'Profile',
    requires: 'announcement:read',
    isNavDestination: true,
    defaultRoles: ['admin', 'staff', 'teacher', 'guardian'],
  },
] as const satisfies readonly ScreenDefinition[];

export type ScreenId = (typeof SCREENS)[number]['id'];

export const SCREEN_IDS = SCREENS.map((s) => s.id) as readonly ScreenId[];

export function screenById(id: string): ScreenDefinition | undefined {
  return SCREENS.find((s) => s.id === id);
}

/** Every `resource:action` pair, flattened. */
export const ALL_PERMISSIONS: readonly Permission[] = Object.entries(RESOURCES).flatMap(
  ([resource, actions]) => actions.map((action) => `${resource}:${action}` as Permission),
);

/** The screens a role gets before any admin customisation. */
export function defaultScreensForRole(role: Role): readonly ScreenId[] {
  return SCREENS.filter((s) => (s.defaultRoles as readonly Role[]).includes(role)).map((s) => s.id);
}

/**
 * The effective policy handed to a client.
 *
 * `version` bumps whenever an admin edits the matrix; the app compares it to
 * the version it has cached and refetches without re-downloading on every
 * launch.
 */
export interface AccessPolicy {
  role: Role;
  permissions: Permission[];
  screens: ScreenId[];
  version: number;
}
