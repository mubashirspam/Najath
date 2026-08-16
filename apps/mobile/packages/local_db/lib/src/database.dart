import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tables.dart';

part 'database.g.dart';

/// The on-device database.
///
/// A relational mirror of what a teacher needs for one working day, plus the
/// sync control tables. Not a mirror of the whole Postgres schema — the server
/// stays the system of record, and anything historic is fetched on demand.
@DriftDatabase(
  tables: [
    Students,
    Departments,
    Batches,
    ClassSections,
    Enrollments,
    AttendanceRecords,
    HifzDailyLogs,
    SyncOutbox,
    SyncCursors,
    SyncMarkers,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'najath'));

  @override
  int get schemaVersion => 1;

  /// Store timestamps as ISO-8601 text, not unix seconds.
  ///
  /// The default loses the timezone, so a sync cursor written as UTC comes back
  /// as local — and the next delta pull asks the server for the wrong window.
  /// Text round-trips exactly.
  @override
  DriftDatabaseOptions get options => const DriftDatabaseOptions(storeDateTimeAsText: true);

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      // The mirror has real foreign keys; without this SQLite ignores them and
      // an orphaned enrollment silently survives a roster refresh.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Drops cached academic data older than [retentionDays], on launch.
  ///
  /// Master data is left alone — a roster is small and re-fetching it on every
  /// start is a worse trade than the rows cost.
  Future<void> pruneOlderThan(int retentionDays) async {
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    final cutoffDate = cutoff.toIso8601String().substring(0, 10);

    await transaction(() async {
      // Never prune a row still waiting to be sent.
      await (delete(attendanceRecords)..where(
            (t) => t.attendanceDate.isSmallerThanValue(cutoffDate) & t.isPending.equals(false),
          ))
          .go();
      await (delete(hifzDailyLogs)..where(
            (t) => t.logDate.isSmallerThanValue(cutoffDate) & t.isPending.equals(false),
          ))
          .go();
    });
  }

  /// Settings → Clear cache. Leaves the outbox alone: unsent work is the user's,
  /// not ours to discard.
  Future<void> clearCachedData() async {
    await transaction(() async {
      await delete(attendanceRecords).go();
      await delete(hifzDailyLogs).go();
      await delete(enrollments).go();
      await delete(students).go();
      await delete(batches).go();
      await delete(classSections).go();
      await delete(departments).go();
      await delete(syncCursors).go();
      await delete(syncMarkers).go();
    });
  }

  /// Sign-out. Everything, including the outbox — a new principal must never
  /// inherit the previous one's queued writes.
  Future<void> wipe() async {
    await transaction(() async {
      await clearCachedData();
      await delete(syncOutbox).go();
    });
  }
}

/// Single database instance for the app's lifetime.
///
/// Overridden in `bootstrap()` with an already-opened instance so the first
/// screen never waits on the file being created.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
