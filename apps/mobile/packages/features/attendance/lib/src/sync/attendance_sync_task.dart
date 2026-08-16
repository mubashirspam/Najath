import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_sync/najath_sync.dart';

/// Keeps today's rosters available offline.
///
/// Registered by the app in `syncTasksProvider`, which is how the engine stays
/// ignorant of every feature. Not one-time: rosters change daily, so this runs
/// on each pass rather than recording a completion marker.
class AttendanceSyncTask extends SyncTask {
  const AttendanceSyncTask();

  @override
  String get id => 'attendance.today';

  @override
  String get entity => 'attendance';

  @override
  String get label => 'attendance';

  @override
  int get order => 20;

  @override
  Future<Result<DateTime?>> run(Ref ref, CancelToken cancelToken) async {
    // Placeholder until M03-API-01 lands. The task is registered now so the
    // pipeline is exercised end to end — the engine's ordering, pacing and
    // cursor handling are the things P0 has to prove, not this body.
    return ok(DateTime.now().toUtc());
  }
}
