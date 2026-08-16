import { sql } from 'drizzle-orm';
import {
  boolean,
  date,
  index,
  jsonb,
  pgTable,
  primaryKey,
  text,
  timestamp,
  unique,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

/** Shared audit columns. Every table that a human can change carries these. */
const stamps = {
  createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
};

// ─────────────────────────── Identity & people ───────────────────────────────

/**
 * A person who can sign in. Staff and guardians have one; **students do not**.
 *
 * Spec §2.3: there is no student role and no student app. Every non-staff path
 * to student data runs `users → guardians → student_guardians → students`.
 *
 * Column names follow **Better Auth's** core schema (`name`, `emailVerified`,
 * `image`) rather than the spec's abridged DDL (`full_name`, `avatar_url`).
 * Better Auth owns authentication, and remapping every core field is a standing
 * source of bugs for no gain. The institution-specific columns below are ours.
 * Passwords live in [accounts], not here — that is Better Auth's model.
 */
export const users = pgTable(
  'users',
  {
    id: uuid().primaryKey().defaultRandom(),
    // --- Better Auth core ---
    name: text().notNull(),
    email: text().unique(),
    emailVerified: boolean().notNull().default(false),
    image: text(),
    // --- ours ---
    phone: text().unique(),
    phoneVerified: boolean().notNull().default(false),
    nameMl: text(),
    locale: text().notNull().default('en'),
    status: text().notNull().default('active'),
    lastSeenAt: timestamp({ withTimezone: true }),
    ...stamps,
  },
  (t) => [
    // Staff sign in by email, guardians by phone. A row with neither cannot
    // authenticate at all, which is a data error rather than a valid state.
    index('users_phone_idx').on(t.phone),
  ],
);

/** Better Auth session. Cookie for the console, bearer token for mobile. */
export const sessions = pgTable(
  'sessions',
  {
    id: uuid().primaryKey().defaultRandom(),
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    token: text().notNull().unique(),
    expiresAt: timestamp({ withTimezone: true }).notNull(),
    ipAddress: text(),
    userAgent: text(),
    /**
     * Which role the mobile shell is currently showing. A user holding several
     * roles switches here without re-authenticating (spec §7.2).
     */
    activeRole: text(),
    ...stamps,
  },
  (t) => [index('sessions_user_idx').on(t.userId)],
);

/** Better Auth credential/provider record. Password hashes live here. */
export const accounts = pgTable(
  'accounts',
  {
    id: uuid().primaryKey().defaultRandom(),
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    accountId: text().notNull(),
    providerId: text().notNull(),
    password: text(),
    accessToken: text(),
    refreshToken: text(),
    idToken: text(),
    accessTokenExpiresAt: timestamp({ withTimezone: true }),
    refreshTokenExpiresAt: timestamp({ withTimezone: true }),
    scope: text(),
    ...stamps,
  },
  (t) => [index('accounts_user_idx').on(t.userId)],
);

/** Better Auth one-time values: email verification and guardian phone OTP. */
export const verifications = pgTable(
  'verifications',
  {
    id: uuid().primaryKey().defaultRandom(),
    identifier: text().notNull(),
    value: text().notNull(),
    expiresAt: timestamp({ withTimezone: true }).notNull(),
    ...stamps,
  },
  (t) => [index('verifications_identifier_idx').on(t.identifier)],
);

/**
 * Role assignment is many-to-many **and scoped**.
 *
 * A DEPT_HEAD is usually also a TEACHER; a TEACHER may be a PARENT of a student
 * in the same college. `scopeType`/`scopeId` narrow the grant — DEPARTMENT for
 * a head, ASSIGNED (resolved through staff_assignments) for a teacher, HOSTEL
 * for a warden. A null scope means the role is institution-wide.
 */
export const userRoles = pgTable(
  'user_roles',
  {
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    role: text().notNull(),
    scopeType: text(),
    scopeId: uuid(),
    grantedBy: uuid().references(() => users.id, { onDelete: 'set null' }),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    // Postgres treats NULLs as distinct in a primary key, so the natural key is
    // expressed as a unique index with NULLS NOT DISTINCT instead — otherwise
    // the same institution-wide role could be granted twice.
    unique('user_roles_natural_key')
      .on(t.userId, t.role, t.scopeType, t.scopeId)
      .nullsNotDistinct(),
    index('user_roles_user_idx').on(t.userId),
  ],
);

/**
 * A student. **A data subject, not a system user.**
 *
 * `userId` is retained for a possible future alumni portal and must never be
 * populated in phases 1–4 (spec §2.3).
 */
export const students = pgTable(
  'students',
  {
    id: uuid().primaryKey().defaultRandom(),
    admissionNo: text().notNull().unique(),
    userId: uuid().references(() => users.id),
    fullName: text().notNull(),
    fullNameMl: text(),
    dob: date(),
    gender: text(),
    bloodGroup: text(),
    photoUrl: text(),
    admissionDate: date().notNull(),
    /** HOSTELLER | DAY_SCHOLAR */
    residency: text().notNull().default('DAY_SCHOLAR'),
    address: jsonb(),
    /** active | alumni | transferred | dropped — never deleted. */
    status: text().notNull().default('active'),
    statusReason: text(),
    statusChangedOn: date(),
    ...stamps,
  },
  (t) => [
    index('students_status_idx').on(t.status),
    index('students_residency_idx').on(t.residency),
  ],
);

export const guardians = pgTable(
  'guardians',
  {
    id: uuid().primaryKey().defaultRandom(),
    userId: uuid().references(() => users.id, { onDelete: 'set null' }),
    fullName: text().notNull(),
    phone: text().notNull(),
    occupation: text(),
    address: jsonb(),
    ...stamps,
  },
  (t) => [index('guardians_phone_idx').on(t.phone)],
);

/**
 * The security-critical table.
 *
 * This is the only path from a non-staff account to a student's record, so an
 * incorrect row shows one family another family's child. Admin-only write path,
 * full audit, and a nightly reconciliation report (M02-JOB-01).
 */
export const studentGuardians = pgTable(
  'student_guardians',
  {
    studentId: uuid()
      .notNull()
      .references(() => students.id, { onDelete: 'cascade' }),
    guardianId: uuid()
      .notNull()
      .references(() => guardians.id, { onDelete: 'cascade' }),
    /** father | mother | brother | uncle | other */
    relation: text().notNull(),
    isPrimary: boolean().notNull().default(false),
    canApproveLeave: boolean().notNull().default(true),
    ...stamps,
  },
  (t) => [
    primaryKey({ columns: [t.studentId, t.guardianId] }),
    index('student_guardians_guardian_idx').on(t.guardianId),
    // At most one primary guardian per student. The "at least one" half cannot
    // be a constraint — it would make the first insert impossible — so it is
    // enforced in the service and reconciled nightly.
    uniqueIndex('student_guardians_one_primary')
      .on(t.studentId)
      .where(sql`${t.isPrimary}`),
  ],
);

export const staff = pgTable('staff', {
  id: uuid().primaryKey().defaultRandom(),
  userId: uuid()
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  employeeNo: text().notNull().unique(),
  designation: text(),
  qualification: text(),
  joiningDate: date(),
  status: text().notNull().default('active'),
  ...stamps,
});

/** Push targets. One row per install, pruned when a token goes stale. */
export const devices = pgTable(
  'devices',
  {
    id: uuid().primaryKey().defaultRandom(),
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    fcmToken: text().notNull().unique(),
    platform: text().notNull(),
    appVersion: text(),
    lastSeenAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index('devices_user_idx').on(t.userId)],
);

// ─────────────────────────── Platform plumbing ───────────────────────────────

/**
 * Every mutation, written in the same transaction as the change.
 *
 * An audit row written after the transaction commits is one that can go missing
 * exactly when it matters.
 */
export const auditLog = pgTable(
  'audit_log',
  {
    id: uuid().primaryKey().defaultRandom(),
    actorId: uuid().references(() => users.id, { onDelete: 'set null' }),
    entity: text().notNull(),
    entityId: uuid(),
    action: text().notNull(),
    before: jsonb(),
    after: jsonb(),
    ip: text(),
    userAgent: text(),
    at: timestamp({ withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index('audit_log_entity_idx').on(t.entity, t.entityId),
    index('audit_log_actor_idx').on(t.actorId, t.at),
  ],
);

/**
 * Replay protection for the mobile outbox.
 *
 * The teacher's phone retrying while the first request is still committing is
 * the normal case on a bad connection, not an edge case. Keys are kept 7 days;
 * a repeat returns the stored response rather than acting twice.
 */
export const idempotencyKeys = pgTable(
  'idempotency_keys',
  {
    key: text().primaryKey(),
    userId: uuid().references(() => users.id, { onDelete: 'cascade' }),
    endpoint: text().notNull(),
    requestHash: text().notNull(),
    responseStatus: text(),
    responseBody: jsonb(),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    expiresAt: timestamp({ withTimezone: true }).notNull(),
  },
  (t) => [index('idempotency_keys_expiry_idx').on(t.expiresAt)],
);

/**
 * Monotonic version of the access configuration. One row, bumped on every
 * matrix edit, so a client that is already current does no work.
 */
export const accessPolicyVersion = pgTable('access_policy_version', {
  id: text().primaryKey().default('singleton'),
  version: text().notNull().default('1'),
  updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
});

/** Per-role screen overrides the admin console writes. Absent row = registry default. */
export const roleScreenAccess = pgTable(
  'role_screen_access',
  {
    role: text().notNull(),
    screenId: text().notNull(),
    allowed: boolean().notNull(),
    updatedBy: uuid().references(() => users.id, { onDelete: 'set null' }),
    updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [primaryKey({ columns: [t.role, t.screenId] })],
);

/** Per-account overrides on top of the role matrix. The escape hatch. */
export const userScreenOverride = pgTable(
  'user_screen_override',
  {
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    screenId: text().notNull(),
    allowed: boolean().notNull(),
    updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [primaryKey({ columns: [t.userId, t.screenId] })],
);
