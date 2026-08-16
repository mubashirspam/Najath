import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';

import 'database.dart';

/// Box-oriented access to the JSON read cache.
///
/// Local data sources hold one of these rather than touching drift directly, so
/// the storage engine stays swappable and every feature reads and writes the
/// cache the same way.
class CacheStore {
  CacheStore(this._db);

  final AppDatabase _db;

  // --- reads ---------------------------------------------------------------

  Future<Map<String, dynamic>?> read(String box, String key) async {
    final row = await (_db.select(
      _db.cacheEntries,
    )..where((t) => t.box.equals(box) & t.key.equals(key))).getSingleOrNull();
    return row == null ? null : _decodeObject(row.value);
  }

  /// Every document in a box.
  Future<List<Map<String, dynamic>>> readAll(String box) async {
    final rows = await (_db.select(_db.cacheEntries)..where((t) => t.box.equals(box))).get();
    return _decodeRows(rows);
  }

  /// Documents in a box sharing a [groupKey] — the indexed "children of X"
  /// read that drill-down screens do constantly.
  Future<List<Map<String, dynamic>>> readGroup(
    String box,
    String groupKey,
  ) async {
    final rows = await (_db.select(
      _db.cacheEntries,
    )..where((t) => t.box.equals(box) & t.groupKey.equals(groupKey))).get();
    return _decodeRows(rows);
  }

  /// Live view of a group. Backs `StreamProvider`s so a write from the sync
  /// engine repaints an open screen without an explicit invalidation.
  Stream<List<Map<String, dynamic>>> watchGroup(String box, String groupKey) {
    return (_db.select(
      _db.cacheEntries,
    )..where((t) => t.box.equals(box) & t.groupKey.equals(groupKey))).watch().map(_decodeRows);
  }

  Stream<List<Map<String, dynamic>>> watchAll(String box) {
    return (_db.select(_db.cacheEntries)..where((t) => t.box.equals(box))).watch().map(_decodeRows);
  }

  Future<int> count(String box) async {
    final countExp = _db.cacheEntries.key.count();
    final query = _db.selectOnly(_db.cacheEntries)
      ..addColumns([countExp])
      ..where(_db.cacheEntries.box.equals(box));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  /// When the freshest row in a box was written, or null if the box is empty.
  /// Drives "cached data is stale, refresh in the background" decisions.
  Future<DateTime?> lastUpdated(String box) async {
    final maxExp = _db.cacheEntries.updatedAt.max();
    final query = _db.selectOnly(_db.cacheEntries)
      ..addColumns([maxExp])
      ..where(_db.cacheEntries.box.equals(box));
    final row = await query.getSingle();
    return row.read(maxExp);
  }

  // --- writes --------------------------------------------------------------

  Future<void> write(
    String box,
    String key,
    Map<String, dynamic> value, {
    String? groupKey,
  }) {
    return _db
        .into(_db.cacheEntries)
        .insertOnConflictUpdate(
          CacheEntriesCompanion.insert(
            box: box,
            key: key,
            value: jsonEncode(value),
            groupKey: Value(groupKey),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Bulk upsert in one transaction — a sync pass writing a whole class roster
  /// should be one commit, not four hundred.
  Future<void> writeAll(
    String box,
    Iterable<Map<String, dynamic>> values, {
    required String Function(Map<String, dynamic>) keyOf,
    String? Function(Map<String, dynamic>)? groupKeyOf,
  }) async {
    final now = DateTime.now();
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        _db.cacheEntries,
        [
          for (final value in values)
            CacheEntriesCompanion.insert(
              box: box,
              key: keyOf(value),
              value: jsonEncode(value),
              groupKey: Value(groupKeyOf?.call(value)),
              updatedAt: Value(now),
            ),
        ],
      );
    });
  }

  /// Replaces a whole group atomically, so a roster that lost a student does
  /// not keep serving them from a stale row.
  Future<void> replaceGroup(
    String box,
    String groupKey,
    Iterable<Map<String, dynamic>> values, {
    required String Function(Map<String, dynamic>) keyOf,
  }) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.cacheEntries,
      )..where((t) => t.box.equals(box) & t.groupKey.equals(groupKey))).go();
      await writeAll(
        box,
        values,
        keyOf: keyOf,
        groupKeyOf: (_) => groupKey,
      );
    });
  }

  Future<void> delete(String box, String key) {
    return (_db.delete(_db.cacheEntries)..where((t) => t.box.equals(box) & t.key.equals(key))).go();
  }

  Future<void> clearBox(String box) {
    return (_db.delete(_db.cacheEntries)..where((t) => t.box.equals(box))).go();
  }

  /// Settings → Clear cache. Leaves preferences and the outbox alone: unsent
  /// work is the user's, not ours to discard.
  Future<void> clearDataCaches() async {
    await (_db.delete(_db.cacheEntries)..where((t) => t.box.isIn(CacheBoxes.clearable))).go();
  }

  /// Everything, including preferences. Used on sign-out so the next principal
  /// never sees the previous one's records.
  Future<void> clearEverything() => _db.delete(_db.cacheEntries).go();

  // --- helpers -------------------------------------------------------------

  List<Map<String, dynamic>> _decodeRows(List<CacheEntry> rows) {
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final decoded = _decodeObject(row.value);
      // Skip corrupt rows rather than failing the read; the next sync
      // overwrites them.
      if (decoded != null) result.add(decoded);
    }
    return result;
  }

  Map<String, dynamic>? _decodeObject(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on Object catch (_) {
      return null;
    }
  }
}

final cacheStoreProvider = Provider<CacheStore>((ref) {
  return CacheStore(ref.watch(appDatabaseProvider));
});
