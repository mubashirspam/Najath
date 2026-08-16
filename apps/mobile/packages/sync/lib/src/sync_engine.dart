import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_local_db/najath_local_db.dart';
import 'package:najath_network/najath_network.dart';

import 'sync_state_store.dart';
import 'sync_task.dart';

/// Stage the engine is currently in. Drives the banner on the dashboard.
enum SyncPhase { idle, uploading, downloading, done, failed }

@immutable
class SyncProgress {
  const SyncProgress({
    this.phase = SyncPhase.idle,
    this.done = 0,
    this.total = 0,
    this.label,
    this.pendingWrites = 0,
    this.lastError,
  });

  final SyncPhase phase;

  /// Items finished / total in the current phase. `total == 0` means the phase
  /// cannot be counted and the banner should show an indeterminate bar.
  final int done;
  final int total;

  /// What is being worked on right now, when known.
  final String? label;

  /// Writes still queued after the last upload attempt.
  final int pendingWrites;

  final String? lastError;

  bool get isActive => phase == SyncPhase.uploading || phase == SyncPhase.downloading;

  double? get fraction => total > 0 ? (done / total).clamp(0.0, 1.0) : null;

  SyncProgress copyWith({
    SyncPhase? phase,
    int? done,
    int? total,
    String? label,
    int? pendingWrites,
    String? lastError,
  }) {
    return SyncProgress(
      phase: phase ?? this.phase,
      done: done ?? this.done,
      total: total ?? this.total,
      label: label ?? this.label,
      pendingWrites: pendingWrites ?? this.pendingWrites,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// The app's single background orchestrator.
///
/// Once sync is *possible* — a transport plus a live session — a pass runs an
/// ordered, paced pipeline entirely in the background:
///
///   1. **Upload.** Drain the outbox, oldest first. Always first: a teacher's
///      unsent attendance must reach the server before anything overwrites the
///      cache it came from.
///   2. **Download.** Every registered [SyncTask] in `order`, paced so the
///      foreground always wins the connection.
///
/// A pass is re-entrancy guarded, losing connectivity cancels the in-flight
/// request and stops the pass, and one-time tasks resume from their markers on
/// the next trigger.
class SyncEngine extends Notifier<SyncProgress> {
  bool _running = false;
  CancelToken _cancelToken = CancelToken();

  @override
  SyncProgress build() => const SyncProgress();

  /// A transport plus a session. Checked before every pass, and again before
  /// each upload, because connectivity can drop mid-pass.
  Future<bool> canSync() async {
    if (!ref.read(isOnlineProvider)) return false;
    final token = await ref.read(tokenStorageProvider).getToken();
    return token != null && token.isNotEmpty;
  }

  /// Stops the current pass. Called when connectivity drops.
  void cancel() {
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel('connectivity lost');
    }
  }

  /// Runs one full pass. Safe to call repeatedly — overlapping calls coalesce
  /// into the single in-flight pass rather than queueing.
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
        // Let the confirmation linger, then fall back to idle so the banner
        // does not sit on screen for the rest of the session.
        Future<void>.delayed(AppDurations.syncDoneLinger, () {
          if (state.phase == SyncPhase.done) {
            state = const SyncProgress();
          }
        });
      }
    } finally {
      _running = false;
    }
  }

  // --- phase 1: upload -----------------------------------------------------

  /// Drains the outbox in creation order.
  ///
  /// Order matters and the queue is not parallelised: a mark created then
  /// amended must reach the server in that sequence, or the amendment loses.
  Future<void> _uploadPhase() async {
    final outbox = ref.read(outboxStoreProvider);
    final client = ref.read(dioClientProvider);

    final due = await outbox.due();
    if (due.isEmpty) return;

    state = state.copyWith(
      phase: SyncPhase.uploading,
      done: 0,
      total: due.length,
      pendingWrites: due.length,
    );

    var sent = 0;
    for (final write in due) {
      if (_cancelToken.isCancelled) break;
      if (!await canSync()) break;

      state = state.copyWith(done: sent, label: write.label ?? write.module);

      final response = await client.request<void>(
        endpoint: write.endpoint,
        method: _methodOf(write.method),
        data: write.payload,
        cancelToken: _cancelToken,
        mapper: (_) {},
      );

      if (response.isCompleted) {
        await outbox.markSent(write.id);
        sent++;
        state = state.copyWith(done: sent);
      } else {
        final error = response.error!;
        if (error.isRetryable) {
          await outbox.markRetryable(write.id, error.message, write.attempts);
          // A retryable failure is almost always the network going away
          // mid-drain. Stop rather than burning through the queue marking
          // everything failed.
          break;
        }
        // Validation, permission, conflict: retrying sends the same bytes and
        // gets the same answer. Park it where the user can see it.
        await outbox.markBlocked(write.id, error.message);
      }

      await Future<void>.delayed(AppDurations.syncPaceGap);
    }

    state = state.copyWith(pendingWrites: await outbox.pendingCount());
  }

  // --- phase 2: download ---------------------------------------------------

  Future<void> _downloadPhase() async {
    final tasks = [...ref.read(syncTasksProvider)]..sort((a, b) => a.order.compareTo(b.order));
    if (tasks.isEmpty) return;

    final markers = ref.read(syncStateStoreProvider);

    final pending = <SyncTask>[];
    for (final task in tasks) {
      if (task.isOneTime && await markers.isDone(task.id)) continue;
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

      try {
        await task.run(ref, _cancelToken);
        if (task.isOneTime) await markers.markDone(task.id);
      } on Object catch (e) {
        // One failing module must not abort the pass — the others still have
        // work worth doing, and this task retries on the next trigger.
        state = state.copyWith(lastError: '${task.label}: $e');
      }

      completed++;
      state = state.copyWith(done: completed);
      await Future<void>.delayed(AppDurations.syncBulkPaceGap);
    }
  }

  HttpMethod _methodOf(String method) => switch (method.toUpperCase()) {
    'POST' => HttpMethod.post,
    'PUT' => HttpMethod.put,
    'PATCH' => HttpMethod.patch,
    'DELETE' => HttpMethod.delete,
    _ => HttpMethod.get,
  };
}

final syncEngineProvider = NotifierProvider<SyncEngine, SyncProgress>(
  SyncEngine.new,
);

/// Watched once by the app shell to keep background sync triggered for the
/// whole session.
///
/// Re-runs a pass when connectivity returns and when a write is queued while
/// online; cancels the in-flight pass when connectivity drops.
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
