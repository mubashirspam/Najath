/**
 * The RBAC model: roles, scopes, resources, and the matrix that binds them.
 *
 * This is the executable form of spec §3. Encoded as data so the policy engine
 * reads it, the admin console renders it, and one table-driven test asserts
 * every cell — rather than the matrix living as `if (role === 'TEACHER')`
 * scattered across route handlers.
 */

export const ROLES = [
  'SUPER_ADMIN',
  'ADMIN',
  'DEPT_HEAD',
  'TEACHER',
  'HOSTEL_WARDEN',
  'CANTEEN_MANAGER',
  'ACCOUNTANT',
  'PARENT',
] as const;

export type Role = (typeof ROLES)[number];

/**
 * How far a grant reaches.
 *
 * A role alone never answers "may this teacher write to batch X" — the scope
 * does. `user_roles` carries `(role, scope_type, scope_id)`, so one user can be
 * DEPT_HEAD of one department and TEACHER of two batches.
 */
export const SCOPE_TYPES = [
  /** The whole institution. */
  'GLOBAL',
  /** One department the user heads. */
  'DEPARTMENT',
  /** Batches and class sections assigned to this user via staff_assignments. */
  'ASSIGNED',
  /** One hostel. */
  'HOSTEL',
  /** Students reachable through student_guardians. */
  'WARD',
  /** The user's own record only. */
  'SELF',
  /** Explicitly nothing. Present so a revocation is expressible. */
  'NONE',
] as const;

export type ScopeType = (typeof SCOPE_TYPES)[number];

export const ACTIONS = ['create', 'read', 'update', 'delete', 'approve'] as const;
export type Action = (typeof ACTIONS)[number];

/** Every resource the policy engine knows, and the actions it supports. */
export const RESOURCES = {
  user: ['create', 'read', 'update', 'delete'],
  student: ['create', 'read', 'update', 'delete'],
  staff: ['create', 'read', 'update', 'delete'],
  academicStructure: ['create', 'read', 'update', 'delete'],
  timetable: ['create', 'read', 'update', 'delete'],
  attendance: ['create', 'read', 'update', 'delete'],
  hifzLog: ['create', 'read', 'update', 'delete'],
  doura: ['create', 'read', 'update', 'delete'],
  exam: ['create', 'read', 'update', 'delete'],
  marks: ['create', 'read', 'update', 'approve'],
  resultPublish: ['read', 'approve'],
  progressReport: ['create', 'read', 'update', 'delete', 'approve'],
  activity: ['create', 'read', 'update', 'delete'],
  leave: ['create', 'read', 'update', 'delete', 'approve'],
  hostel: ['create', 'read', 'update', 'delete'],
  canteen: ['create', 'read', 'update', 'delete'],
  announcement: ['create', 'read', 'update', 'delete'],
  report: ['read'],
} as const satisfies Record<string, readonly Action[]>;

export type Resource = keyof typeof RESOURCES;

/** `resource:action`, the wire form of a single permission. */
export type Permission = {
  [R in Resource]: `${R}:${(typeof RESOURCES)[R][number]}`;
}[Resource];

export interface Grant {
  readonly actions: readonly Action[];
  readonly scope: ScopeType;
  /**
   * A state condition the *service layer* must also enforce. The policy engine
   * cannot check it — it needs the record — so this exists to make the rule
   * discoverable rather than folklore.
   */
  readonly condition?: string;
}

const CRUD = ['create', 'read', 'update', 'delete'] as const;
const CRU = ['create', 'read', 'update'] as const;
const CR = ['create', 'read'] as const;
const RU = ['read', 'update'] as const;
const R = ['read'] as const;

/**
 * Spec §3, executable.
 *
 * A missing resource means no access. Read this next to the table in the spec —
 * they must agree, and the policy test asserts it.
 */
export const RBAC = {
  SUPER_ADMIN: {
    user: { actions: CRUD, scope: 'GLOBAL' },
    student: { actions: CRUD, scope: 'GLOBAL' },
    staff: { actions: CRUD, scope: 'GLOBAL' },
    academicStructure: { actions: CRUD, scope: 'GLOBAL' },
    timetable: { actions: CRUD, scope: 'GLOBAL' },
    attendance: { actions: CRUD, scope: 'GLOBAL' },
    // Read and void only: nobody edits another teacher's hifz log, including
    // the principal. Corrections supersede.
    hifzLog: { actions: ['read', 'delete'], scope: 'GLOBAL' },
    doura: { actions: ['read', 'delete'], scope: 'GLOBAL' },
    exam: { actions: CRUD, scope: 'GLOBAL' },
    marks: { actions: R, scope: 'GLOBAL' },
    resultPublish: { actions: ['read', 'approve'], scope: 'GLOBAL' },
    progressReport: { actions: CRUD, scope: 'GLOBAL' },
    activity: { actions: R, scope: 'GLOBAL' },
    leave: { actions: ['create', 'read', 'update', 'delete', 'approve'], scope: 'GLOBAL' },
    hostel: { actions: CRUD, scope: 'GLOBAL' },
    canteen: { actions: CRUD, scope: 'GLOBAL' },
    announcement: { actions: CRUD, scope: 'GLOBAL' },
    report: { actions: R, scope: 'GLOBAL' },
  },

  ADMIN: {
    user: { actions: CR, scope: 'GLOBAL' },
    student: { actions: CRUD, scope: 'GLOBAL' },
    staff: { actions: CRUD, scope: 'GLOBAL' },
    academicStructure: { actions: CRUD, scope: 'GLOBAL' },
    timetable: { actions: CRUD, scope: 'GLOBAL' },
    attendance: { actions: CRUD, scope: 'GLOBAL' },
    hifzLog: { actions: R, scope: 'GLOBAL' },
    doura: { actions: R, scope: 'GLOBAL' },
    exam: { actions: CRUD, scope: 'GLOBAL' },
    marks: { actions: R, scope: 'GLOBAL' },
    resultPublish: { actions: ['read', 'approve'], scope: 'GLOBAL' },
    progressReport: { actions: CR, scope: 'GLOBAL' },
    activity: { actions: R, scope: 'GLOBAL' },
    leave: { actions: ['create', 'read', 'update', 'delete', 'approve'], scope: 'GLOBAL' },
    hostel: { actions: CRUD, scope: 'GLOBAL' },
    canteen: { actions: CRUD, scope: 'GLOBAL' },
    announcement: { actions: CRUD, scope: 'GLOBAL' },
    report: { actions: R, scope: 'GLOBAL' },
  },

  DEPT_HEAD: {
    user: { actions: R, scope: 'GLOBAL' },
    student: { actions: R, scope: 'DEPARTMENT' },
    staff: { actions: RU, scope: 'DEPARTMENT' },
    academicStructure: { actions: RU, scope: 'DEPARTMENT' },
    timetable: { actions: CRUD, scope: 'DEPARTMENT' },
    attendance: { actions: RU, scope: 'DEPARTMENT' },
    hifzLog: { actions: RU, scope: 'DEPARTMENT' },
    doura: { actions: CRU, scope: 'DEPARTMENT' },
    exam: { actions: CRUD, scope: 'DEPARTMENT' },
    marks: { actions: ['read', 'update', 'approve'], scope: 'DEPARTMENT' },
    resultPublish: { actions: ['read', 'approve'], scope: 'DEPARTMENT' },
    progressReport: { actions: ['create', 'read', 'approve'], scope: 'DEPARTMENT' },
    activity: { actions: R, scope: 'DEPARTMENT' },
    leave: { actions: ['read', 'approve'], scope: 'DEPARTMENT' },
    hostel: { actions: R, scope: 'GLOBAL' },
    announcement: { actions: CRUD, scope: 'DEPARTMENT' },
    report: { actions: R, scope: 'DEPARTMENT' },
  },

  TEACHER: {
    student: { actions: R, scope: 'ASSIGNED' },
    staff: { actions: R, scope: 'SELF' },
    academicStructure: { actions: R, scope: 'ASSIGNED' },
    timetable: { actions: R, scope: 'ASSIGNED' },
    attendance: {
      actions: CRU,
      scope: 'ASSIGNED',
      condition: 'same calendar day only; beyond that needs an admin unlock',
    },
    hifzLog: {
      actions: CRU,
      scope: 'ASSIGNED',
      condition: 'backdating limited to institution setting hifzBackdateDays',
    },
    doura: { actions: CRU, scope: 'ASSIGNED' },
    exam: { actions: CRU, scope: 'ASSIGNED' },
    marks: {
      actions: CRU,
      scope: 'ASSIGNED',
      condition: 'pre-publish only; locked after verified',
    },
    progressReport: { actions: ['create'], scope: 'ASSIGNED', condition: 'draft remarks only' },
    activity: { actions: CRU, scope: 'ASSIGNED' },
    leave: {
      actions: ['create', 'approve'],
      scope: 'ASSIGNED',
      condition: 'approve for own class; create for self',
    },
    hostel: { actions: R, scope: 'GLOBAL' },
    announcement: { actions: ['create'], scope: 'ASSIGNED' },
    report: { actions: R, scope: 'ASSIGNED' },
  },

  HOSTEL_WARDEN: {
    student: { actions: R, scope: 'HOSTEL' },
    attendance: { actions: CRU, scope: 'HOSTEL', condition: 'hostel roll call only' },
    activity: { actions: CRU, scope: 'HOSTEL' },
    leave: { actions: ['read', 'approve'], scope: 'HOSTEL' },
    hostel: { actions: CRUD, scope: 'HOSTEL' },
    canteen: { actions: R, scope: 'HOSTEL' },
    announcement: { actions: ['create'], scope: 'HOSTEL' },
    report: { actions: R, scope: 'HOSTEL' },
  },

  CANTEEN_MANAGER: {
    // Canteen module only — deliberately no student read. Meal capture resolves
    // students through the canteen service, which returns names and nothing else.
    canteen: { actions: CRUD, scope: 'GLOBAL' },
    report: { actions: R, scope: 'GLOBAL' },
  },

  ACCOUNTANT: {
    student: { actions: R, scope: 'GLOBAL' },
    attendance: { actions: R, scope: 'GLOBAL' },
    exam: { actions: R, scope: 'GLOBAL' },
    marks: { actions: R, scope: 'GLOBAL' },
    canteen: { actions: CRUD, scope: 'GLOBAL', condition: 'billing and ledger' },
    report: { actions: R, scope: 'GLOBAL' },
  },

  PARENT: {
    student: { actions: R, scope: 'WARD' },
    timetable: { actions: R, scope: 'WARD' },
    attendance: { actions: R, scope: 'WARD' },
    hifzLog: { actions: R, scope: 'WARD' },
    doura: { actions: R, scope: 'WARD' },
    resultPublish: { actions: R, scope: 'WARD', condition: 'published results only' },
    progressReport: { actions: R, scope: 'WARD', condition: 'published reports only' },
    activity: { actions: R, scope: 'WARD', condition: 'visible_to includes PARENT' },
    leave: {
      actions: ['create', 'read'],
      scope: 'WARD',
      condition: 'guardian must have can_approve_leave',
    },
    hostel: { actions: R, scope: 'WARD' },
    canteen: { actions: R, scope: 'WARD' },
    announcement: { actions: R, scope: 'WARD' },
    report: { actions: R, scope: 'WARD' },
  },
} as const satisfies Record<Role, Partial<Record<Resource, Grant>>>;

/** Every `resource:action` pair, flattened. */
export const ALL_PERMISSIONS: readonly Permission[] = Object.entries(RESOURCES).flatMap(
  ([resource, actions]) => actions.map((action) => `${resource}:${action}` as Permission),
);

/** The permissions a role holds, ignoring scope. */
export function permissionsForRole(role: Role): readonly Permission[] {
  const grants = RBAC[role] as Partial<Record<Resource, Grant>>;
  return Object.entries(grants).flatMap(([resource, grant]) =>
    grant.actions.map((action) => `${resource}:${action}` as Permission),
  );
}

/** The scope a role's grant on a resource reaches, or null if it has none. */
export function scopeFor(role: Role, resource: Resource): ScopeType | null {
  const grant = (RBAC[role] as Partial<Record<Resource, Grant>>)[resource];
  return grant?.scope ?? null;
}

export function grantFor(role: Role, resource: Resource): Grant | null {
  return (RBAC[role] as Partial<Record<Resource, Grant>>)[resource] ?? null;
}

/** Whether any of a user's roles permits `resource:action`, ignoring scope. */
export function roleAllows(roles: readonly Role[], resource: Resource, action: Action): boolean {
  return roles.some((role) => grantFor(role, resource)?.actions.includes(action) ?? false);
}

/**
 * The widest scope any of the user's roles gives on a resource.
 *
 * GLOBAL beats DEPARTMENT beats ASSIGNED, and so on — a DEPT_HEAD who also
 * teaches sees their whole department, not just their batches.
 */
const SCOPE_BREADTH: Record<ScopeType, number> = {
  GLOBAL: 6,
  DEPARTMENT: 5,
  HOSTEL: 4,
  ASSIGNED: 3,
  WARD: 2,
  SELF: 1,
  NONE: 0,
};

export function widestScope(
  roles: readonly Role[],
  resource: Resource,
  action: Action,
): ScopeType | null {
  const scopes = roles
    .map((role) => grantFor(role, resource))
    .filter((grant): grant is Grant => !!grant && grant.actions.includes(action))
    .map((grant) => grant.scope);

  if (scopes.length === 0) return null;
  return scopes.reduce((widest, s) => (SCOPE_BREADTH[s] > SCOPE_BREADTH[widest] ? s : widest));
}

/** Staff roles sign in with email + password; PARENT signs in with phone OTP. */
export const STAFF_ROLES: readonly Role[] = ROLES.filter((r) => r !== 'PARENT');

export function isStaffRole(role: Role): boolean {
  return role !== 'PARENT';
}
