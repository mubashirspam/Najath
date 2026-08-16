import 'package:najath_network/najath_network.dart';

import '../entities/attendance.dart';

abstract class AttendanceRepository {
  /// Sessions, cache-first. [forceRefresh] skips the cache when the user pulls
  /// to refresh.
  Future<ApiResponse<List<AttendanceSession>>> sessions({
    String? classId,
    bool forceRefresh = false,
  });

  /// A session's roster, cache-first.
  Future<ApiResponse<List<AttendanceMark>>> marks(
    String sessionId, {
    bool forceRefresh = false,
  });

  /// Live roster, repainted whenever the cache changes — from a sync pass or
  /// from this device's own optimistic writes.
  Stream<List<AttendanceMark>> watchMarks(String sessionId);

  /// Records a status. Writes the cache immediately and queues the request, so
  /// the caller never waits on the network and never loses the mark.
  Future<void> markStudent({
    required String sessionId,
    required String studentId,
    required String studentName,
    required AttendanceStatus status,
    String? note,
  });
}
