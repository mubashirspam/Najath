import { sql } from 'drizzle-orm';
import {
  boolean,
  index,
  integer,
  pgTable,
  primaryKey,
  text,
  timestamp,
  uniqueIndex,
} from 'drizzle-orm/pg-core';

import { user } from './auth';

/**
 * The role → screen matrix the admin console edits.
 *
 * The registry in `@najath/contracts` defines which screens *exist* and which
 * permission each one needs; this table records which of them a role is
 * currently allowed to open. A row is only written when an admin diverges from
 * the registry default, so an untouched academy runs entirely on the defaults
 * and an upgrade that adds a screen does not need a data migration.
 */
export const roleScreenAccess = pgTable(
  'role_screen_access',
  {
    role: text().notNull(),
    screenId: text().notNull(),
    allowed: boolean().notNull(),
    updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedBy: text().references(() => user.id, { onDelete: 'set null' }),
  },
  (t) => [primaryKey({ columns: [t.role, t.screenId] })],
);

/**
 * Per-role permission overrides.
 *
 * Screens control what is reachable; permissions control what the API will do.
 * Kept separate because revoking `attendance:amend` must close every screen
 * that needs it, wherever it appears — a screen-level toggle cannot express
 * that.
 */
export const rolePermissionOverride = pgTable(
  'role_permission_override',
  {
    role: text().notNull(),
    permission: text().notNull(),
    granted: boolean().notNull(),
    updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedBy: text().references(() => user.id, { onDelete: 'set null' }),
  },
  (t) => [primaryKey({ columns: [t.role, t.permission] })],
);

/**
 * Monotonic version of the whole access configuration.
 *
 * One row, bumped on every matrix edit. The mobile app caches its policy and
 * compares versions, so a device that is already current does no work — and a
 * device that is stale finds out on its next call rather than after a 403.
 */
export const accessPolicyVersion = pgTable('access_policy_version', {
  id: integer().primaryKey().default(1),
  version: integer().notNull().default(1),
  updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
});

/**
 * Overrides for a single account, on top of whatever its role grants.
 *
 * The escape hatch every academy eventually needs: one teacher who also runs
 * the hostel, without inventing a fifth role.
 */
export const userScreenOverride = pgTable(
  'user_screen_override',
  {
    userId: text()
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    screenId: text().notNull(),
    allowed: boolean().notNull(),
    updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    primaryKey({ columns: [t.userId, t.screenId] }),
    index('user_screen_override_user_idx').on(t.userId),
  ],
);

/**
 * Which students a guardian may see.
 *
 * Screen access says a guardian can open Attendance; this says whose attendance.
 * Enforced server-side on every query — the client never sends a student id the
 * API trusts.
 */
export const guardianStudent = pgTable(
  'guardian_student',
  {
    guardianId: text()
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    studentId: text().notNull(),
    relationship: text(),
    isPrimary: boolean().notNull().default(false),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    primaryKey({ columns: [t.guardianId, t.studentId] }),
    index('guardian_student_student_idx').on(t.studentId),
  ],
);

/**
 * Staff assignment: which classes a teacher is responsible for.
 *
 * The teacher equivalent of [guardianStudent] — the row filter behind every
 * "my classes" query.
 */
export const staffAssignment = pgTable(
  'staff_assignment',
  {
    userId: text()
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    classId: text().notNull(),
    isClassTeacher: boolean().notNull().default(false),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    primaryKey({ columns: [t.userId, t.classId] }),
    // Partial unique index: at most one class teacher per class, while any
    // number of subject teachers can be assigned to it.
    uniqueIndex('staff_assignment_class_teacher_idx')
      .on(t.classId)
      .where(sql`${t.isClassTeacher}`),
  ],
);
