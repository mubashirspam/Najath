import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

/// A queued write, in the shape the sync engine replays it.
class PendingWrite {
  const PendingWrite({
    required this.id,
    required this.entity,
    required this.operation,
    required this.endpoint,
    required this.payload,
    required this.idempotencyKey,
    required this.attempts,
    required this.createdAt,
    this.label,
    this.lastError,
    this.isBlocked = false,
  });

  factory PendingWrite.fromRow(SyncOutboxData row) {
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(row.payload);
      payload = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on Object catch (_) {
      payload = <String, dynamic>{};
    }
    return PendingWrite(
      id: row.id,
      entity: row.entity,
      operation: row.operation,
      endpoint: row.endpoint,
      payload: payload,
      idempotencyKey: row.idempotencyKey,
      attempts: row.attempts,
      createdAt: row.createdAt,
      label: row.label,
      lastError: row.lastError,
      isBlocked: row.isBlocked,
    );
  }

  final String id;
  final String entity;
  final String operation;
  final String endpoint;
  final Map<String, dynamic> payload;
  final String idempotencyKey;
  final int attempts;
  final DateTime createdAt;
  final String? label;
  final String? lastError;
  final bool isBlocked;
}

/// The offline write queue.
///
/// Every mutation a teacher makes lands here first, so the UI can commit
/// immediately and the network becomes a background concern.
class OutboxStore {
  OutboxStore(this._db);

  final AppDatabase _db;

  /// Queues a write.
  ///
  /// [id] is the record's own client-generated UUID v7 — the same id the row
  /// carries in its table, so a replay writes the same row rather than a
  /// duplicate. Re-queuing the same id replaces the unsent entry: correcting a
  /// mark three times offline must produce one request carrying the final
  /// answer.
  Future<void> enqueue({
    required String id,
    required String entity,
    required String operation,
    required String endpoint,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
    String? label,
  }) async {
    await _db
        .into(_db.syncOutbox)
        .insertOnConflictUpdate(
          SyncOutboxCompanion.insert(
            id: id,
            entity: entity,
            operation: operation,
            endpoint: endpoint,
            payload: jsonEncode(payload),
            idempotencyKey: idempotencyKey,
            label: Value(label),
            createdAt: DateTime.now(),
          ),
        );
  }

  /// The next batch to send for one entity, oldest first.
  ///
  /// Per entity because ordering only has to hold within one: an attendance
  /// mark and a hifz log are independent, but two edits of the same mark are
  /// not.
  Future<List<PendingWrite>> dueFor(String entity, {int limit = 50}) async {
    final now = DateTime.now();
    final rows =
        await (_db.select(_db.syncOutbox)
              ..where((t) => t.entity.equals(entity) & t.isBlocked.equals(false))
              ..where(
                (t) => t.nextAttemptAt.isNull() | t.nextAttemptAt.isSmallerOrEqualValue(now),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
              ..limit(limit))
            .get();
    return rows.map(PendingWrite.fromRow).toList();
  }

  /// Entities that currently have anything queued, so the engine only walks
  /// the queues that exist.
  Future<List<String>> pendingEntities() async {
    final query = _db.selectOnly(_db.syncOutbox, distinct: true)
      ..addColumns([_db.syncOutbox.entity])
      ..where(_db.syncOutbox.isBlocked.equals(false));
    final rows = await query.get();
    return rows.map((r) => r.read(_db.syncOutbox.entity)!).toList();
  }

  /// Everything still queued, for the "unsynced work" screen.
  Stream<List<PendingWrite>> watchAll() {
    return (_db.select(_db.syncOutbox)..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(PendingWrite.fromRow).toList());
  }

  Future<int> pendingCount() async {
    final countExp = _db.syncOutbox.id.count();
    final query = _db.selectOnly(_db.syncOutbox)
      ..addColumns([countExp])
      ..where(_db.syncOutbox.isBlocked.equals(false));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  /// Whether a specific record is still waiting. Drives the per-row "will send"
  /// marker on a roster.
  Future<Set<String>> pendingIds(String entity) async {
    final rows = await (_db.select(
      _db.syncOutbox,
    )..where((t) => t.entity.equals(entity) & t.isBlocked.equals(false))).get();
    return rows.map((r) => r.id).toSet();
  }

  Stream<Set<String>> watchPendingIds(String entity) {
    return (_db.select(_db.syncOutbox)
          ..where((t) => t.entity.equals(entity) & t.isBlocked.equals(false)))
        .watch()
        .map((rows) => rows.map((r) => r.id).toSet());
  }

  Future<void> markSent(String id) {
    return (_db.delete(_db.syncOutbox)..where((t) => t.id.equals(id))).go();
  }

  /// Records a retryable failure and pushes the entry into exponential backoff,
  /// capped so a long outage does not park a write for hours.
  Future<void> markRetryable(String id, String error, int attempts) {
    final delaySeconds = (1 << attempts.clamp(0, 6)) * 5;
    final now = DateTime.now();
    return (_db.update(_db.syncOutbox)..where((t) => t.id.equals(id))).write(
      SyncOutboxCompanion(
        attempts: Value(attempts + 1),
        lastError: Value(error),
        lastAttemptAt: Value(now),
        nextAttemptAt: Value(now.add(Duration(seconds: delaySeconds))),
      ),
    );
  }

  /// Records a failure retrying cannot fix. The entry stays visible so the user
  /// can see what was rejected and discard it deliberately.
  Future<void> markBlocked(String id, String error) {
    return (_db.update(_db.syncOutbox)..where((t) => t.id.equals(id))).write(
      SyncOutboxCompanion(
        isBlocked: const Value(true),
        lastError: Value(error),
        lastAttemptAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> discard(String id) => markSent(id);
}

/// Where each entity's delta pull got to.
class SyncCursorStore {
  SyncCursorStore(this._db);

  final AppDatabase _db;

  Future<DateTime?> lastPulled(String entity) async {
    final row = await (_db.select(
      _db.syncCursors,
    )..where((t) => t.entity.equals(entity))).getSingleOrNull();
    return row?.lastPulledAt;
  }

  /// Stores the cursor the **server** returned, not local time — a device clock
  /// that is minutes fast would silently skip rows.
  Future<void> setCursor(String entity, DateTime serverTime) {
    return _db
        .into(_db.syncCursors)
        .insertOnConflictUpdate(
          SyncCursorsCompanion.insert(entity: entity, lastPulledAt: serverTime),
        );
  }

  Future<bool> isDone(String taskId) async {
    final row = await (_db.select(
      _db.syncMarkers,
    )..where((t) => t.taskId.equals(taskId))).getSingleOrNull();
    return row != null;
  }

  Future<void> markDone(String taskId) {
    return _db
        .into(_db.syncMarkers)
        .insertOnConflictUpdate(
          SyncMarkersCompanion.insert(taskId: taskId, completedAt: DateTime.now()),
        );
  }
}

final outboxStoreProvider = Provider<OutboxStore>((ref) {
  return OutboxStore(ref.watch(appDatabaseProvider));
});

final syncCursorStoreProvider = Provider<SyncCursorStore>((ref) {
  return SyncCursorStore(ref.watch(appDatabaseProvider));
});

/// Live view of unsent writes, for the sync banner and the nav badge.
final pendingWritesProvider = StreamProvider<List<PendingWrite>>((ref) {
  return ref.watch(outboxStoreProvider).watchAll();
});
