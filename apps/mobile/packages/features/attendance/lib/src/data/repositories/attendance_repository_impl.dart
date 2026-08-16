import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_local_db/najath_local_db.dart';
import 'package:najath_network/najath_network.dart';

import '../../domain/entities/attendance.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../data_sources/attendance_sources.dart';
import '../models/attendance_dtos.dart';

/// Offline-first attendance.
///
/// Reads serve the cache first and fall back to the network on a miss. Writes
/// go the other way round — cache first, always, then the outbox — because a
/// teacher taking roll in a hall with no signal cannot be asked to wait.
class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl({
    required AttendanceRemoteSource remote,
    required AttendanceLocalSource local,
    required OutboxStore outbox,
    required bool Function() isOnline,
  }) : _remote = remote,
       _local = local,
       _outbox = outbox,
       _isOnline = isOnline;

  final AttendanceRemoteSource _remote;
  final AttendanceLocalSource _local;
  final OutboxStore _outbox;
  final bool Function() _isOnline;

  @override
  Future<ApiResponse<List<AttendanceSession>>> sessions({
    String? classId,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _local.sessions();
      if (cached.isNotEmpty) {
        // Warm the cache in the background so the next open is current, but
        // return what we already have immediately.
        if (_isOnline()) unawaited(_refreshSessions(classId));
        return ApiResponse.completed(
          cached.map((dto) => dto.toEntity()).toList(),
        );
      }
    }

    if (!_isOnline()) {
      return ApiResponse.error(ApiError.unavailableOffline());
    }

    final res = await _remote.fetchSessions(classId: classId);
    if (!res.hasData) return res.castError<List<AttendanceSession>>();

    await _local.saveSessions(res.data!);
    return ApiResponse.completed(
      res.data!.map((dto) => dto.toEntity()).toList(),
    );
  }

  @override
  Future<ApiResponse<List<AttendanceMark>>> marks(
    String sessionId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && await _local.hasMarks(sessionId)) {
      final cached = await _local.marks(sessionId);
      return ApiResponse.completed(await _withPendingFlags(sessionId, cached));
    }

    if (!_isOnline()) {
      return ApiResponse.error(ApiError.unavailableOffline());
    }

    final res = await _remote.fetchMarks(sessionId);
    if (!res.hasData) return res.castError<List<AttendanceMark>>();

    // Do not let a refresh clobber marks still sitting in the outbox: the
    // server's copy is older than the teacher's unsent correction.
    final pendingIds = await _pendingStudentIds(sessionId);
    final incoming = res.data!;
    if (pendingIds.isEmpty) {
      await _local.saveMarks(sessionId, incoming);
    } else {
      final local = await _local.marks(sessionId);
      final localById = {for (final m in local) m.studentId: m};
      await _local.saveMarks(sessionId, [
        for (final mark in incoming)
          if (pendingIds.contains(mark.studentId)) localById[mark.studentId] ?? mark else mark,
      ]);
    }

    final merged = await _local.marks(sessionId);
    return ApiResponse.completed(await _withPendingFlags(sessionId, merged));
  }

  @override
  Stream<List<AttendanceMark>> watchMarks(String sessionId) {
    return _local.watchMarks(sessionId).asyncMap((dtos) async {
      return _withPendingFlags(sessionId, dtos);
    });
  }

  @override
  Future<void> markStudent({
    required String sessionId,
    required String studentId,
    required String studentName,
    required AttendanceStatus status,
    String? note,
  }) async {
    final dto = AttendanceMarkDto(
      sessionId: sessionId,
      studentId: studentId,
      studentName: studentName,
      status: status.name,
      note: note,
    );

    // Local first — the roster repaints on the next frame either way.
    await _local.upsertMark(dto);

    // One queue entry per student per session: correcting a mark three times
    // offline must still send one request, carrying the final answer.
    await _outbox.enqueue(
      endpoint: ApiEndpoints.attendanceMarks(sessionId),
      method: 'POST',
      payload: dto.toJson(),
      module: 'attendance',
      dedupeKey: 'attendance:$sessionId:$studentId',
      label: '$studentName — ${status.label}',
    );
  }

  Future<void> _refreshSessions(String? classId) async {
    final res = await _remote.fetchSessions(classId: classId);
    if (res.hasData) await _local.saveSessions(res.data!);
  }

  Future<Set<String>> _pendingStudentIds(String sessionId) async {
    final queued = await _outbox.due(limit: 500);
    final prefix = 'attendance:$sessionId:';
    return {
      for (final write in queued)
        if (write.dedupeKey != null && write.dedupeKey!.startsWith(prefix))
          write.dedupeKey!.substring(prefix.length),
    };
  }

  Future<List<AttendanceMark>> _withPendingFlags(
    String sessionId,
    List<AttendanceMarkDto> dtos,
  ) async {
    final pending = await _pendingStudentIds(sessionId);
    return dtos.map((dto) => dto.toEntity(isPending: pending.contains(dto.studentId))).toList();
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepositoryImpl(
    remote: ref.watch(attendanceRemoteSourceProvider),
    local: ref.watch(attendanceLocalSourceProvider),
    outbox: ref.watch(outboxStoreProvider),
    isOnline: () => ref.read(isOnlineProvider),
  );
});
