import { createAccessControl } from 'better-auth/plugins/access';
import { defaultStatements, adminAc } from 'better-auth/plugins/admin/access';

/**
 * Resource → action map. Extend as modules land; every ERP module that needs
 * authorization should register its resource here rather than string-matching
 * roles at the call site.
 */
export const statement = {
  ...defaultStatements,
  student: ['create', 'read', 'update', 'delete'],
  attendance: ['read', 'mark', 'amend'],
  hifz: ['read', 'record', 'verify'],
  exam: ['read', 'create', 'grade', 'publish'],
  leave: ['read', 'request', 'approve'],
  hostel: ['read', 'manage'],
  canteen: ['read', 'manage'],
  announcement: ['read', 'publish'],
  report: ['read', 'export'],
} as const;

export const ac = createAccessControl(statement);

/** Full access. Principal / IT. */
export const admin = ac.newRole({
  ...adminAc.statements,
  student: ['create', 'read', 'update', 'delete'],
  attendance: ['read', 'mark', 'amend'],
  hifz: ['read', 'record', 'verify'],
  exam: ['read', 'create', 'grade', 'publish'],
  leave: ['read', 'request', 'approve'],
  hostel: ['read', 'manage'],
  canteen: ['read', 'manage'],
  announcement: ['read', 'publish'],
  report: ['read', 'export'],
});

/** Academic office: manages records, cannot administer accounts. */
export const staff = ac.newRole({
  student: ['create', 'read', 'update'],
  attendance: ['read', 'mark', 'amend'],
  hifz: ['read', 'record', 'verify'],
  exam: ['read', 'create', 'grade', 'publish'],
  leave: ['read', 'approve'],
  hostel: ['read', 'manage'],
  canteen: ['read', 'manage'],
  announcement: ['read', 'publish'],
  report: ['read', 'export'],
});

/** Classroom teacher / halaqah ustadh. */
export const teacher = ac.newRole({
  student: ['read'],
  attendance: ['read', 'mark'],
  hifz: ['read', 'record'],
  exam: ['read', 'grade'],
  leave: ['read'],
  announcement: ['read'],
  report: ['read'],
});

/**
 * Guardian — the only non-staff principal that can log in (phone OTP).
 * Read-only against their own wards; row scoping is enforced in @najath/core,
 * not here.
 */
export const guardian = ac.newRole({
  student: ['read'],
  attendance: ['read'],
  hifz: ['read'],
  exam: ['read'],
  leave: ['read', 'request'],
  announcement: ['read'],
});

export const roles = { admin, staff, teacher, guardian };

export type AppRole = keyof typeof roles;
