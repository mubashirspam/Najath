import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_sync/najath_sync.dart';

import '../data/data_sources/attendance_sources.dart';

/// Keeps recent attendance available offline.
///
/// Registered by the app in `syncTasksProvider`, which is how the engine stays
/// ignorant of every feature. Not one-time: sessions change daily, so this runs
/// on each pass rather than recording a completion marker.
class AttendanceSyncTask extends SyncTask {
  const AttendanceSyncTask();

  @override
  String get id => 'attendance.recent';

  @override
  String get label => 'attendance';

  @override
  int get order => 20;

  @override
  Future<void> run(Ref ref, CancelToken cancelToken) async {
    final remote = ref.read(attendanceRemoteSourceProvider);
    final local = ref.read(attendanceLocalSourceProvider);

    final since = DateTime.now().subtract(const Duration(days: 30));
    final sessions = await remote.fetchSessions(from: since);
    if (!sessions.hasData) return;

    await local.saveSessions(sessions.data!);

    // Prefetch rosters for sessions that are not finished, so a teacher who
    // loses signal mid-period can still complete the roll call.
    for (final session in sessions.data!.where((s) => !s.isFinalised)) {
      if (cancelToken.isCancelled) return;
      final marks = await remote.fetchMarks(session.id);
      if (marks.hasData) {
        await local.saveMarks(session.id, marks.data!);
      }
    }
  }
}
