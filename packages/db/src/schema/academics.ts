import { sql } from 'drizzle-orm';
import {
  boolean,
  date,
  index,
  integer,
  pgTable,
  smallint,
  text,
  time,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

import { staff, students } from './identity';

const stamps = {
  createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
};

/**
 * The institution. Single-tenant in practice — Hufzul Quran College — but
 * carried as a row so the platform is not rebuilt for the second customer.
 */
export const institutions = pgTable('institutions', {
  id: uuid().primaryKey().defaultRandom(),
  code: text().notNull().unique(),
  name: text().notNull(),
  nameMl: text(),
  timezone: text().notNull().default('Asia/Kolkata'),
  locale: text().notNull().default('en'),
  letterheadUrl: text(),
  ...stamps,
});

export const academicYears = pgTable(
  'academic_years',
  {
    id: uuid().primaryKey().defaultRandom(),
    institutionId: uuid()
      .notNull()
      .references(() => institutions.id, { onDelete: 'cascade' }),
    /** '1447 AH / 2026-27' */
    name: text().notNull(),
    startDate: date().notNull(),
    endDate: date().notNull(),
    isCurrent: boolean().notNull().default(false),
    ...stamps,
  },
  (t) => [
    // Exactly one current year, enforced rather than assumed — every query that
    // omits a year falls back to this one.
    uniqueIndex('academic_years_one_current')
      .on(t.institutionId)
      .where(sql`${t.isCurrent}`),
  ],
);

/**
 * The three departments. A student is enrolled in one or more simultaneously —
 * typically Hifz in the morning and General Education in the afternoon — which
 * is why every academic record is department-scoped.
 */
export const departments = pgTable('departments', {
  id: uuid().primaryKey().defaultRandom(),
  institutionId: uuid()
    .notNull()
    .references(() => institutions.id, { onDelete: 'cascade' }),
  /** HIFZ | ISLAMIC | GENERAL */
  code: text().notNull().unique(),
  name: text().notNull(),
  nameMl: text(),
  /** HIFZ_DOURA | SUBJECT_BASED */
  kind: text().notNull(),
  /** FULL_DAY | SESSION | PERIOD — attendance granularity for this department. */
  attendanceMode: text().notNull().default('FULL_DAY'),
  ...stamps,
});

/** A Hifz halaqa: small, teacher-owned. */
export const batches = pgTable(
  'batches',
  {
    id: uuid().primaryKey().defaultRandom(),
    departmentId: uuid()
      .notNull()
      .references(() => departments.id, { onDelete: 'cascade' }),
    academicYearId: uuid()
      .notNull()
      .references(() => academicYears.id, { onDelete: 'cascade' }),
    name: text().notNull(),
    /** NAZIRA | HIFZ | DOURA */
    level: text(),
    inchargeStaffId: uuid().references(() => staff.id, { onDelete: 'set null' }),
    capacity: integer(),
    ...stamps,
  },
  (t) => [
    uniqueIndex('batches_name_per_year').on(t.academicYearId, t.departmentId, t.name),
    index('batches_incharge_idx').on(t.inchargeStaffId),
  ],
);

export const classSections = pgTable(
  'class_sections',
  {
    id: uuid().primaryKey().defaultRandom(),
    departmentId: uuid()
      .notNull()
      .references(() => departments.id, { onDelete: 'cascade' }),
    academicYearId: uuid()
      .notNull()
      .references(() => academicYears.id, { onDelete: 'cascade' }),
    className: text().notNull(),
    section: text(),
    classTeacherId: uuid().references(() => staff.id, { onDelete: 'set null' }),
    ...stamps,
  },
  (t) => [
    uniqueIndex('class_sections_unique').on(
      t.academicYearId,
      t.departmentId,
      t.className,
      t.section,
    ),
  ],
);

export const subjects = pgTable(
  'subjects',
  {
    id: uuid().primaryKey().defaultRandom(),
    departmentId: uuid()
      .notNull()
      .references(() => departments.id, { onDelete: 'cascade' }),
    code: text().notNull(),
    name: text().notNull(),
    nameMl: text(),
    maxMarks: integer().notNull().default(100),
    passMarks: integer().notNull().default(35),
    isGradable: boolean().notNull().default(true),
    ...stamps,
  },
  (t) => [uniqueIndex('subjects_code_per_department').on(t.departmentId, t.code)],
);

/**
 * **The universal academic foreign key.**
 *
 * One row per student per department per academic year. Attendance, hifz logs,
 * marks and reports all point here — never at `student_id` alone, because "the
 * student's attendance" is not a question this system can answer.
 */
export const enrollments = pgTable(
  'enrollments',
  {
    id: uuid().primaryKey().defaultRandom(),
    studentId: uuid()
      .notNull()
      .references(() => students.id, { onDelete: 'cascade' }),
    academicYearId: uuid()
      .notNull()
      .references(() => academicYears.id, { onDelete: 'cascade' }),
    departmentId: uuid()
      .notNull()
      .references(() => departments.id, { onDelete: 'cascade' }),
    batchId: uuid().references(() => batches.id, { onDelete: 'set null' }),
    classSectionId: uuid().references(() => classSections.id, { onDelete: 'set null' }),
    rollNo: text(),
    status: text().notNull().default('active'),
    ...stamps,
  },
  (t) => [
    uniqueIndex('enrollments_unique').on(t.studentId, t.academicYearId, t.departmentId),
    // The two hot lookups: a teacher opening a roster, and a guardian opening
    // a ward.
    index('enrollments_batch_idx').on(t.batchId),
    index('enrollments_class_idx').on(t.classSectionId),
    index('enrollments_student_idx').on(t.studentId),
  ],
);

/**
 * What a staff member is responsible for. This is how the `ASSIGNED` scope
 * resolves — a teacher's batches and class sections.
 */
export const staffAssignments = pgTable(
  'staff_assignments',
  {
    id: uuid().primaryKey().defaultRandom(),
    staffId: uuid()
      .notNull()
      .references(() => staff.id, { onDelete: 'cascade' }),
    academicYearId: uuid()
      .notNull()
      .references(() => academicYears.id, { onDelete: 'cascade' }),
    departmentId: uuid()
      .notNull()
      .references(() => departments.id, { onDelete: 'cascade' }),
    batchId: uuid().references(() => batches.id, { onDelete: 'cascade' }),
    classSectionId: uuid().references(() => classSections.id, { onDelete: 'cascade' }),
    subjectId: uuid().references(() => subjects.id, { onDelete: 'cascade' }),
    /** INCHARGE | SUBJECT_TEACHER | ASSISTANT */
    role: text().notNull(),
    ...stamps,
  },
  (t) => [
    index('staff_assignments_staff_idx').on(t.staffId, t.academicYearId),
    index('staff_assignments_batch_idx').on(t.batchId),
    index('staff_assignments_class_idx').on(t.classSectionId),
  ],
);

/**
 * Timetable slots are **versioned by effective date**. Historical attendance
 * must resolve against the timetable that was live on that date, not today's.
 */
export const timetableSlots = pgTable(
  'timetable_slots',
  {
    id: uuid().primaryKey().defaultRandom(),
    academicYearId: uuid()
      .notNull()
      .references(() => academicYears.id, { onDelete: 'cascade' }),
    departmentId: uuid()
      .notNull()
      .references(() => departments.id, { onDelete: 'cascade' }),
    classSectionId: uuid().references(() => classSections.id, { onDelete: 'cascade' }),
    batchId: uuid().references(() => batches.id, { onDelete: 'cascade' }),
    /** 0 = Sunday … 6 = Saturday */
    dayOfWeek: smallint().notNull(),
    periodNo: smallint(),
    subjectId: uuid().references(() => subjects.id, { onDelete: 'set null' }),
    staffId: uuid().references(() => staff.id, { onDelete: 'set null' }),
    startTime: time().notNull(),
    endTime: time().notNull(),
    room: text(),
    effectiveFrom: date().notNull(),
    effectiveTo: date(),
    ...stamps,
  },
  (t) => [
    index('timetable_slots_class_day_idx').on(t.classSectionId, t.dayOfWeek),
    index('timetable_slots_batch_day_idx').on(t.batchId, t.dayOfWeek),
    // Clash detection queries this: what else is this teacher doing then?
    index('timetable_slots_staff_day_idx').on(t.staffId, t.dayOfWeek, t.startTime),
  ],
);

/**
 * Working days, **per department**. Hifz often runs on days General Education
 * does not, which is why attendance percentages are department-scoped.
 *
 * ⛔ Blocked on client question Q11 for the actual calendar.
 */
export const holidays = pgTable(
  'holidays',
  {
    id: uuid().primaryKey().defaultRandom(),
    academicYearId: uuid()
      .notNull()
      .references(() => academicYears.id, { onDelete: 'cascade' }),
    /** Null means every department. */
    departmentId: uuid().references(() => departments.id, { onDelete: 'cascade' }),
    holidayDate: date().notNull(),
    name: text().notNull(),
    ...stamps,
  },
  (t) => [index('holidays_date_idx').on(t.academicYearId, t.holidayDate)],
);
