import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_local_db/najath_local_db.dart';
import 'package:najath_network/najath_network.dart';

import 'sync_task.dart';

/// Stage the engine is in. Drives the banner on the shell.
enum SyncPhase { idle, uploading, downloading, done, failed }

@immutable
class SyncProgress {
  const SyncProgress({
    this.phase = SyncPhase.idle,
    this.done = 0,
    this.total = 0,
    this.label,
    this.pendingWrites = 0,
    this.lastFailure,
  });

  final SyncPhase phase;
  final int done;
  final int total;
  final String? label;
  final int pendingWrites;
  final Failure? lastFailure;

  bool get isActive => phase == SyncPhase.uploading || phase == SyncPhase.downloading;

  double? get fraction => total > 0 ? (done / total).clamp(0.0, 1.0) : null;

  SyncProgress copyWith({
    SyncPhase? phase,
    int? done,
    int? total,
    String? label,
    int? pendingWrites,
    Failure? lastFailure,
  }) {
    return SyncProgress(
      phase: phase ?? this.phase,
      done: done ?? this.done,
      total: total ?? this.total,
      label: label ?? this.label,
      pendingWrites: pendingWrites ?? this.pendingWrites,
      lastFailure: lastFailure ?? this.lastFailure,
    );
  }
}

/// The app's single background orchestrator.
///
/// Once sync is *possible* — a transport plus a live session — a pass runs an
/// ordered, paced pipeline in the background:
///
///   1. **Upload.** Drain the outbox, FIFO per entity. Always first: a
///      teacher's unsent mark must reach the server before a download
///      overwrites the row it came from.
///   2. **Download.** Every registered [SyncTask] in `order`, paced so the
///      foreground always wins the connection.
///
/// A pass is re-entrancy guarded; losing connectivity cancels the in-flight
/// request and stops the pass; one-time tasks resume from their markers.
class SyncEngine extends Notifier<SyncProgress> {
  bool _running = false;
  CancelToken _cancelToken = CancelToken();

  @override
  SyncProgress build() => const SyncProgress();

  /// A transport plus a session.
  Future<bool> canSync() async {
    if (!ref.read(isOnlineProvider)) return false;
    final token = await ref.read(tokenStorageProvider).getToken();
    return token != null && token.isNotEmpty;
  }

  void cancel() {
    if (!_cancelToken.isCancelled) _cancelToken.cancel('connectivity lost');
  }

  /// Runs one full pass. Overlapping calls coalesce into the in-flight pass
  /// rather than queueing.
  Future<void> run() async {
    if (_running) return;
    if (!await canSync()) return;

    _running = true;
    if (_cancelToken.isCancelled) _cancelToken = CancelToken();

    try {
      await _uploadPhase();
      if (_cancelToken.isCancelled) return;
      await _downloadPhase();

      if (!_cancelToken.isCancelled) {
        state = state.copyWith(
          phase: SyncPhase.done,
          pendingWrites: await ref.read(outboxStoreProvider).pendingCount(),
        );
        unawaited(
          Future<void>.delayed(AppDurations.syncDoneLinger, () {
            if (state.phase == SyncPhase.done) state = const SyncProgress();
          }),
        );
      }
    } finally {
      _running = false;
    }
  }

  // ── phase 1: upload ────────────────────────────────────────────────────────

  /// Drains each entity's queue in creation order.
  ///
  /// FIFO **per entity**: a mark created then amended must reach the server in
  /// that sequence or the amendment loses. Across entities order does not
  /// matter and serialising them would only slow the pass down.
  Future<void> _uploadPhase() async {
    final outbox = ref.read(outboxStoreProvider);
    final client = ref.read(dioClientProvider);

    final entities = await outbox.pendingEntities();
    if (entities.isEmpty) return;

    final queued = await outbox.pendingCount();
    state = state.copyWith(
      phase: SyncPhase.uploading,
      done: 0,
      total: queued,
      pendingWrites: queued,
    );

    var sent = 0;

    for (final entity in entities) {
      if (_cancelToken.isCancelled) break;

      for (final write in await outbox.dueFor(entity)) {
        if (_cancelToken.isCancelled) break;
        if (!await canSync()) return;

        state = state.copyWith(done: sent, label: write.label ?? write.entity);

        final result = await client.request<void>(
          endpoint: write.endpoint,
          method: _methodOf(write.operation),
          data: write.payload,
          idempotencyKey: write.idempotencyKey,
          cancelToken: _cancelToken,
          decode: (_) {},
        );

        final stop = await result.fold(
          (failure) async {
            if (failure is UnauthorizedFailure) {
              // The queue is never dropped on a 401. The auth layer refreshes
              // and the next trigger resumes exactly here.
              return true;
            }
            if (failure.isRetryable) {
              await outbox.markRetryable(write.id, failure.code, write.attempts);
              // Almost always the network going away mid-drain. Stop rather
              // than burning through the queue marking everything failed.
              return true;
            }
            // Validation, permission, conflict: retrying sends the same bytes
            // and gets the same answer. Park it where the user can see it.
            await outbox.markBlocked(write.id, failure.code);
            state = state.copyWith(lastFailure: failure);
            return false;
          },
          (_) async {
            await outbox.markSent(write.id);
            await _clearPendingFlag(entity, write.id);
            sent++;
            state = state.copyWith(done: sent);
            return false;
          },
        );

        if (stop) {
          state = state.copyWith(pendingWrites: await outbox.pendingCount());
          return;
        }

        await Future<void>.delayed(AppDurations.syncPaceGap);
      }
    }

    state = state.copyWith(pendingWrites: await outbox.pendingCount());
  }

  /// Clears the row's "will send" marker once the server has it.
  ///
  /// The engine knows entity names but not their tables, so this is the one
  /// place it maps between them. A new entity that forgets to register here
  /// keeps a stale marker — visible, not silent.
  Future<void> _clearPendingFlag(String entity, String id) async {
    switch (entity) {
      case 'attendance':
        await ref.read(attendanceDaoProvider).clearPendingFlag(id);
      default:
        break;
    }
  }

  // ── phase 2: download ──────────────────────────────────────────────────────

  Future<void> _downloadPhase() async {
    final tasks = [...ref.read(syncTasksProvider)]..sort((a, b) => a.order.compareTo(b.order));
    if (tasks.isEmpty) return;

    final cursors = ref.read(syncCursorStoreProvider);

    final pending = <SyncTask>[];
    for (final task in tasks) {
      if (task.isOneTime && await cursors.isDone(task.id)) continue;
      pending.add(task);
    }
    if (pending.isEmpty) return;

    state = state.copyWith(
      phase: SyncPhase.downloading,
      done: 0,
      total: pending.length,
    );

    var completed = 0;
    for (final task in pending) {
      if (_cancelToken.isCancelled) break;
      if (!await canSync()) break;

      state = state.copyWith(done: completed, label: task.label);

      final result = await task.run(ref, _cancelToken);

      await result.fold(
        (failure) async {
          // One failing module must not abort the pass — the others still have
          // work worth doing, and this task retries on the next trigger.
          state = state.copyWith(lastFailure: failure);
        },
        (serverTime) async {
          if (serverTime != null) await cursors.setCursor(task.entity, serverTime);
          if (task.isOneTime) await cursors.markDone(task.id);
        },
      );

      completed++;
      state = state.copyWith(done: completed);
      await Future<void>.delayed(AppDurations.syncBulkPaceGap);
    }
  }

  HttpMethod _methodOf(String operation) => switch (operation) {
    'update' => HttpMethod.patch,
    'void' => HttpMethod.delete,
    _ => HttpMethod.post,
  };
}

final syncEngineProvider = NotifierProvider<SyncEngine, SyncProgress>(
  SyncEngine.new,
);

/// Watched once by the app shell to keep background sync triggered for the
/// whole session.
final syncKeepAliveProvider = Provider<void>((ref) {
  ref
    ..listen<bool>(isOnlineProvider, (wasOnline, isOnline) {
      final engine = ref.read(syncEngineProvider.notifier);
      if (isOnline) {
        unawaited(engine.run());
      } else {
        engine.cancel();
      }
    })
    ..listen(pendingWritesProvider, (previous, next) {
      final queued = next.value?.where((w) => !w.isBlocked).length ?? 0;
      if (queued > 0 && ref.read(isOnlineProvider)) {
        unawaited(ref.read(syncEngineProvider.notifier).run());
      }
    });
});
