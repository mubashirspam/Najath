import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_local_db/najath_local_db.dart';

/// Persisted "this has already been done" markers for one-time sync tasks.
///
/// Lives in the clearable part of the cache, so Settings → Clear cache forces a
/// full re-sync — which is exactly what a user reaching for that button wants.
class SyncStateStore {
  SyncStateStore(this._cache);

  final CacheStore _cache;

  Future<bool> isDone(String taskId) async {
    final row = await _cache.read(CacheBoxes.syncState, taskId);
    return row?['done'] == true;
  }

  Future<void> markDone(String taskId) {
    return _cache.write(CacheBoxes.syncState, taskId, {
      'done': true,
      'at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> reset(String taskId) => _cache.delete(CacheBoxes.syncState, taskId);

  Future<void> resetAll() => _cache.clearBox(CacheBoxes.syncState);
}

final syncStateStoreProvider = Provider<SyncStateStore>((ref) {
  return SyncStateStore(ref.watch(cacheStoreProvider));
});
