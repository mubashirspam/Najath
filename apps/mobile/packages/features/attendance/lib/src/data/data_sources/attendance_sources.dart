import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_local_db/najath_local_db.dart';
import 'package:najath_network/najath_network.dart';

import '../models/attendance_dtos.dart';

/// Reads and writes the offline cache for attendance.
///
/// Marks are grouped by session id so opening a roster is a single indexed
/// read rather than a scan of every mark the device has ever cached.
class AttendanceLocalSource {
  AttendanceLocalSource(this._cache);

  final CacheStore _cache;

  Future<List<AttendanceSessionDto>> sessions() async {
    final rows = await _cache.readAll(CacheBoxes.attendanceSessions);
    return rows.map(AttendanceSessionDto.fromJson).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Stream<List<AttendanceSessionDto>> watchSessions() {
    return _cache.watchAll(CacheBoxes.attendanceSessions).map((rows) {
      return rows.map(AttendanceSessionDto.fromJson).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    });
  }

  Future<void> saveSessions(List<AttendanceSessionDto> sessions) {
    return _cache.writeAll(
      CacheBoxes.attendanceSessions,
      sessions.map((s) => s.toJson()),
      keyOf: (json) => json['id']! as String,
      groupKeyOf: (json) => json['classId'] as String?,
    );
  }

  Future<List<AttendanceMarkDto>> marks(String sessionId) async {
    final rows = await _cache.readGroup(CacheBoxes.attendanceMarks, sessionId);
    return rows.map(AttendanceMarkDto.fromJson).toList()
      ..sort((a, b) => a.studentName.compareTo(b.studentName));
  }

  Stream<List<AttendanceMarkDto>> watchMarks(String sessionId) {
    return _cache.watchGroup(CacheBoxes.attendanceMarks, sessionId).map((rows) {
      return rows.map(AttendanceMarkDto.fromJson).toList()
        ..sort((a, b) => a.studentName.compareTo(b.studentName));
    });
  }

  /// Replaces the whole roster atomically — a student who left the class must
  /// not linger from a stale row.
  Future<void> saveMarks(String sessionId, List<AttendanceMarkDto> marks) {
    return _cache.replaceGroup(
      CacheBoxes.attendanceMarks,
      sessionId,
      marks.map((m) => m.toJson()),
      keyOf: (json) => '$sessionId:${json['studentId']}',
    );
  }

  /// Applies one mark locally, ahead of the server. This is what makes the
  /// roster feel instant and keeps working with no signal at all.
  Future<void> upsertMark(AttendanceMarkDto mark) {
    return _cache.write(
      CacheBoxes.attendanceMarks,
      '${mark.sessionId}:${mark.studentId}',
      mark.toJson(),
      groupKey: mark.sessionId,
    );
  }

  Future<bool> hasMarks(String sessionId) async {
    final rows = await _cache.readGroup(CacheBoxes.attendanceMarks, sessionId);
    return rows.isNotEmpty;
  }
}

class AttendanceRemoteSource {
  AttendanceRemoteSource(this._client);

  final DioClient _client;

  Future<ApiResponse<List<AttendanceSessionDto>>> fetchSessions({
    String? classId,
    DateTime? from,
  }) {
    return _client.get<List<AttendanceSessionDto>>(
      endpoint: ApiEndpoints.attendanceSessions,
      queryParameters: {
        'classId': ?classId,
        'from': ?from?.toIso8601String(),
      },
      mapper: (body) => (body as List)
          .whereType<Map<String, dynamic>>()
          .map(AttendanceSessionDto.fromJson)
          .toList(),
    );
  }

  Future<ApiResponse<List<AttendanceMarkDto>>> fetchMarks(String sessionId) {
    return _client.get<List<AttendanceMarkDto>>(
      endpoint: ApiEndpoints.attendanceMarks(sessionId),
      mapper: (body) =>
          (body as List).whereType<Map<String, dynamic>>().map(AttendanceMarkDto.fromJson).toList(),
    );
  }
}

final attendanceLocalSourceProvider = Provider<AttendanceLocalSource>((ref) {
  return AttendanceLocalSource(ref.watch(cacheStoreProvider));
});

final attendanceRemoteSourceProvider = Provider<AttendanceRemoteSource>((ref) {
  return AttendanceRemoteSource(ref.watch(dioClientProvider));
});
