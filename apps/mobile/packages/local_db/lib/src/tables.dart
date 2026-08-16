import 'package:drift/drift.dart';

/// The local mirror is **relational**, not a blob store.
///
/// Drift was chosen over Hive precisely because the offline data has joins in
/// it — student → enrollment → batch → hifz log. A roster screen is one query
/// here; against a key-value cache it is N reads and a manual join in Dart.
///
/// Only what a teacher needs for one working day is mirrored. Everything older
/// than `LOCAL_RETENTION_DAYS` is pruned on launch and fetched on demand.

// ─────────────────────────────── Master data ─────────────────────────────────

@TableIndex(name: 'students_admission_idx', columns: {#admissionNo})
class Students extends Table {
  TextColumn get id => text()();
  TextColumn get admissionNo => text()();
  TextColumn get fullName => text()();
  TextColumn get fullNameMl => text().nullable()();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get residency => text().withDefault(const Constant('DAY_SCHOLAR'))();
  TextColumn get status => text().withDefault(const Constant('active'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Departments extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()();

  /// FULL_DAY | SESSION | PERIOD — decides which attendance flow this
  /// department's screens use.
  TextColumn get attendanceMode => text().withDefault(const Constant('FULL_DAY'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// `Batch` is taken by drift's own batch API, so the row class is BatchRow.
@DataClassName('BatchRow')
@TableIndex(name: 'batches_department_idx', columns: {#departmentId})
class Batches extends Table {
  TextColumn get id => text()();
  TextColumn get departmentId => text().references(Departments, #id)();
  TextColumn get name => text()();
  TextColumn get level => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'class_sections_department_idx', columns: {#departmentId})
class ClassSections extends Table {
  TextColumn get id => text()();
  TextColumn get departmentId => text().references(Departments, #id)();
  TextColumn get className => text()();
  TextColumn get section => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The universal academic foreign key, mirrored.
///
/// Nothing local is keyed by `studentId` alone either — a student in Hifz and
/// General Education has two enrollments, and their attendance differs.
@TableIndex(name: 'enrollments_batch_idx', columns: {#batchId})
@TableIndex(name: 'enrollments_class_idx', columns: {#classSectionId})
@TableIndex(name: 'enrollments_student_idx', columns: {#studentId})
class Enrollments extends Table {
  TextColumn get id => text()();
  TextColumn get studentId => text().references(Students, #id)();
  TextColumn get departmentId => text().references(Departments, #id)();
  TextColumn get batchId => text().nullable().references(Batches, #id)();
  TextColumn get classSectionId => text().nullable().references(ClassSections, #id)();
  TextColumn get rollNo => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ─────────────────────────── Academic records ────────────────────────────────

/// Append-only, exactly as on the server.
///
/// A correction inserts a new row carrying `supersedesId` and flips
/// `isCurrent` on the old one. Reads filter `isCurrent` — the history stays so
/// a guardian disputing a mark can be shown what changed and when.
@TableIndex(name: 'attendance_enrollment_date_idx', columns: {#enrollmentId, #attendanceDate})
@TableIndex(name: 'attendance_date_idx', columns: {#attendanceDate})
class AttendanceRecords extends Table {
  /// Client-generated UUID v7. The server accepts it; there is no remapping.
  TextColumn get id => text()();
  TextColumn get enrollmentId => text().references(Enrollments, #id)();

  /// A calendar date in Asia/Kolkata, stored `YYYY-MM-DD`. Deliberately not a
  /// `DateTime`: a 6 AM Fajr halaqa must not file against yesterday because a
  /// UTC instant said so.
  TextColumn get attendanceDate => text()();

  /// FULL_DAY | FORENOON | AFTERNOON | PERIOD
  TextColumn get session => text()();
  TextColumn get timetableSlotId => text().nullable()();

  /// PRESENT | ABSENT | LATE | LEAVE | HALF_DAY | EXCUSED
  TextColumn get status => text()();
  IntColumn get minutesLate => integer().nullable()();
  TextColumn get remark => text().nullable()();
  TextColumn get markedBy => text().nullable()();
  DateTimeColumn get markedAt => dateTime()();
  TextColumn get supersedesId => text().nullable()();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(true))();

  /// True while this row exists only on the device. Drives the "will send"
  /// marker so a teacher can tell saved-here from saved-on-the-server.
  BoolColumn get isPending => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'hifz_enrollment_date_idx', columns: {#enrollmentId, #logDate})
@TableIndex(name: 'hifz_batch_date_idx', columns: {#batchId, #logDate})
class HifzDailyLogs extends Table {
  TextColumn get id => text()();
  TextColumn get enrollmentId => text().references(Enrollments, #id)();
  TextColumn get batchId => text().references(Batches, #id)();
  TextColumn get logDate => text()();

  /// SABAQ | SABQI | MANZIL | DOURA | NAZIRA
  TextColumn get activity => text()();

  IntColumn get fromSurah => integer()();
  IntColumn get fromAyah => integer()();
  IntColumn get toSurah => integer()();
  IntColumn get toAyah => integer()();

  /// Derived from the bundled ayah index, never entered.
  IntColumn get fromPage => integer().nullable()();
  IntColumn get toPage => integer().nullable()();
  IntColumn get linesCount => integer().nullable()();
  IntColumn get juzNo => integer().nullable()();

  TextColumn get douraRoundId => text().nullable()();
  IntColumn get errorsMajor => integer().withDefault(const Constant(0))();
  IntColumn get errorsMinor => integer().withDefault(const Constant(0))();

  /// Luqma — the single best quality signal.
  IntColumn get promptsCount => integer().withDefault(const Constant(0))();

  /// EXCELLENT | GOOD | AVERAGE | WEAK | NOT_READY
  TextColumn get grade => text().nullable()();
  BoolColumn get isRepeat => boolean().withDefault(const Constant(false))();
  TextColumn get teacherRemark => text().nullable()();
  TextColumn get audioUrl => text().nullable()();
  TextColumn get loggedBy => text().nullable()();
  DateTimeColumn get loggedAt => dateTime()();
  TextColumn get supersedesId => text().nullable()();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(true))();
  BoolColumn get isPending => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ─────────────────────────────── Sync control ────────────────────────────────

/// Writes that have not reached the server yet.
///
/// The app never blocks a teacher on connectivity: a mark is committed to the
/// tables above and queued here, and the sync engine drains it in order.
@TableIndex(name: 'outbox_entity_created_idx', columns: {#entity, #createdAt})
class SyncOutbox extends Table {
  /// Client-generated UUID v7, same id as the record it carries.
  TextColumn get id => text()();

  /// 'attendance' | 'hifz_log' | … — the queue drains FIFO *per entity*.
  TextColumn get entity => text()();

  /// create | update | void
  TextColumn get operation => text()();

  TextColumn get endpoint => text()();
  TextColumn get payload => text()();

  /// `sha256(entity + clientId + naturalKey)`. The server dedupes on this for
  /// seven days, which is what makes replay safe.
  TextColumn get idempotencyKey => text()();

  /// Human-readable summary for the unsynced-work screen.
  TextColumn get label => text().nullable()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  /// Rejected in a way retrying cannot fix — validation, permission, conflict.
  /// Stays in the table so the user can see it and discard it deliberately.
  BoolColumn get isBlocked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Where the last delta pull got to, per entity.
///
/// Without this there is no incremental sync: every resume would refetch
/// everything, which on a halaqa's connection is the difference between two
/// seconds and two minutes.
class SyncCursors extends Table {
  TextColumn get entity => text()();
  DateTimeColumn get lastPulledAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {entity};
}

/// One-time "this has been done" markers for bulk sync tasks.
class SyncMarkers extends Table {
  TextColumn get taskId => text()();
  DateTimeColumn get completedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {taskId};
}
