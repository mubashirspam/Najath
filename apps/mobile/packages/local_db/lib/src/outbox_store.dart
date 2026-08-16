import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';

const _uuid = Uuid();

/// A queued write, in the shape the sync engine replays it.
class PendingWrite {
  const PendingWrite({
    required this.id,
    required this.endpoint,
    required this.method,
    required this.payload,
    required this.module,
    required this.attempts,
    required this.createdAt,
    this.dedupeKey,
    this.label,
    this.lastError,
    this.isBlocked = false,
    this.nextAttemptAt,
  });

  factory PendingWrite.fromRow(OutboxEntry row) {
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(row.payload);
      payload = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on Object catch (_) {
      payload = <String, dynamic>{};
    }
    return PendingWrite(
      id: row.id,
      endpoint: row.endpoint,
      method: row.method,
      payload: payload,
      module: row.module,
      attempts: row.attempts,
      createdAt: row.createdAt,
      dedupeKey: row.dedupeKey,
      label: row.label,
      lastError: row.lastError,
      isBlocked: row.isBlocked,
      nextAttemptAt: row.nextAttemptAt,
    );
  }

  final String id;
  final String endpoint;
  final String method;
  final Map<String, dynamic> payload;
  final String module;
  final int attempts;
  final DateTime createdAt;
  final String? dedupeKey;
  final String? label;
  final String? lastError;
  final bool isBlocked;
  final DateTime? nextAttemptAt;
}

/// The offline write queue.
///
/// Every mutation a teacher or guardian makes goes through here first, so the
/// UI can commit immediately and the network becomes a background concern.
class OutboxStore {
  OutboxStore(this._db);

  final AppDatabase _db;

  /// Queues a write.
  ///
  /// When [dedupeKey] is supplied, an existing unsent entry with the same key
  /// is replaced instead of a second one being added — correcting the same
  /// attendance mark twice offline must produce one request, and the later
  /// value must win.
  Future<String> enqueue({
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
    required String module,
    String? dedupeKey,
    String? label,
  }) async {
    final id = _uuid.v4();
    await _db.transaction(() async {
      if (dedupeKey != null) {
        await (_db.delete(_db.outboxEntries)..where(
              (t) => t.dedupeKey.equals(dedupeKey) & t.isBlocked.equals(false),
            ))
            .go();
      }
      await _db
          .into(_db.outboxEntries)
          .insert(
            OutboxEntriesCompanion.insert(
              id: id,
              endpoint: endpoint,
              method: method,
              payload: jsonEncode(payload),
              module: module,
              dedupeKey: Value(dedupeKey),
              label: Value(label),
            ),
          );
    });
    return id;
  }

  /// The next batch to send, oldest first, skipping blocked entries and any
  /// still inside their backoff window.
  Future<List<PendingWrite>> due({int limit = 25}) async {
    final now = DateTime.now();
    final rows =
        await (_db.select(_db.outboxEntries)
              ..where((t) => t.isBlocked.equals(false))
              ..where(
                (t) => t.nextAttemptAt.isNull() | t.nextAttemptAt.isSmallerOrEqualValue(now),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
              ..limit(limit))
            .get();
    return rows.map(PendingWrite.fromRow).toList();
  }

  /// Everything still queued, for the "unsynced work" screen.
  Stream<List<PendingWrite>> watchAll() {
    return (_db.select(_db.outboxEntries)..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(PendingWrite.fromRow).toList());
  }

  Future<int> pendingCount() async {
    final countExp = _db.outboxEntries.id.count();
    final query = _db.selectOnly(_db.outboxEntries)
      ..addColumns([countExp])
      ..where(_db.outboxEntries.isBlocked.equals(false));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<void> markSent(String id) {
    return (_db.delete(_db.outboxEntries)..where((t) => t.id.equals(id))).go();
  }

  /// Records a retryable failure and pushes the entry into exponential backoff,
  /// capped so a long outage does not park a write for hours.
  Future<void> markRetryable(String id, String error, int attempts) {
    final delaySeconds = (1 << attempts.clamp(0, 6)) * 5;
    return (_db.update(_db.outboxEntries)..where((t) => t.id.equals(id))).write(
      OutboxEntriesCompanion(
        attempts: Value(attempts + 1),
        lastError: Value(error),
        nextAttemptAt: Value(
          DateTime.now().add(Duration(seconds: delaySeconds)),
        ),
      ),
    );
  }

  /// Records a failure retrying cannot fix. The entry stays visible so the user
  /// can see what was lost and discard it deliberately.
  Future<void> markBlocked(String id, String error) {
    return (_db.update(_db.outboxEntries)..where((t) => t.id.equals(id))).write(
      OutboxEntriesCompanion(
        isBlocked: const Value(true),
        lastError: Value(error),
      ),
    );
  }

  Future<void> discard(String id) => markSent(id);

  Future<void> clear() => _db.delete(_db.outboxEntries).go();
}

final outboxStoreProvider = Provider<OutboxStore>((ref) {
  return OutboxStore(ref.watch(appDatabaseProvider));
});

/// Live count of unsent writes, for the sync banner and the nav badge.
final pendingWritesProvider = StreamProvider<List<PendingWrite>>((ref) {
  return ref.watch(outboxStoreProvider).watchAll();
});
