import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tables.dart';

part 'database.g.dart';

/// The on-device database.
///
/// Two concerns only: a JSON read cache the app serves screens from while
/// offline, and the outbox of writes that have not reached the server. Neither
/// is a mirror of the Postgres schema — the server stays the system of record.
@DriftDatabase(tables: [CacheEntries, OutboxEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'najath'));

  /// In-memory instance for tests.
  AppDatabase.memory() : super(driftDatabase(name: 'najath_test'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
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
