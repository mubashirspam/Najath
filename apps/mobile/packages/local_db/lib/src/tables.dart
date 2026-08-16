import 'package:drift/drift.dart';

/// One cached server document, stored as JSON text.
///
/// Deliberately schemaless: the cache mirrors whatever the API returned, so a
/// backend field addition never needs a client migration. Anything that needs
/// real columns and joins gets its own table instead — this is the read cache,
/// not the domain model.
@TableIndex(name: 'cache_box_key', columns: {#box, #key})
@TableIndex(name: 'cache_box_group', columns: {#box, #groupKey})
class CacheEntries extends Table {
  /// Logical partition, from `CacheBoxes`.
  TextColumn get box => text()();

  /// Identity of the document within its box, usually the server id.
  TextColumn get key => text()();

  /// Optional secondary key for "all rows belonging to X" reads — a class id
  /// for students, a session id for attendance marks — so the common query is
  /// an index hit rather than a full-box scan and decode.
  TextColumn get groupKey => text().nullable()();

  TextColumn get value => text()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {box, key};
}

/// A write that has not reached the server yet.
///
/// The app never blocks a teacher on connectivity: an attendance mark or a hifz
/// entry is committed locally and parked here, and the sync engine drains the
/// queue in order once a transport is available.
class OutboxEntries extends Table {
  TextColumn get id => text()();

  /// Ordering and de-duplication key. Two edits of the same target collapse to
  /// the latest — a teacher correcting a mark twice offline should produce one
  /// request, not two.
  TextColumn get dedupeKey => text().nullable()();

  TextColumn get endpoint => text()();
  TextColumn get method => text()();

  /// JSON request body.
  TextColumn get payload => text()();

  /// Which feature enqueued this, so a failure can be reported where it
  /// happened and the queue screen can group by module.
  TextColumn get module => text()();

  /// Human-readable summary for the unsynced-work screen.
  TextColumn get label => text().nullable()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Last failure, kept so a permanently rejected write can explain itself
  /// instead of retrying forever in silence.
  TextColumn get lastError => text().nullable()();

  /// Set once the server has rejected the write in a way retrying cannot fix
  /// (validation, permission). Stays in the table so the user can see and
  /// discard it deliberately.
  BoolColumn get isBlocked => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
