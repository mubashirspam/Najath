import 'package:najath_core/najath_core.dart';

import '../entities/attendance.dart';

abstract class AttendanceRepository {
  /// The roster, streamed from the **local database**.
  ///
  /// A stream and not a future: the UI has exactly one data path. A sync pass,
  /// an outbox drain and this device's own optimistic writes all land in
  /// SQLite, and SQLite pushes to the screen. Offline correctness is then a
  /// property of the architecture rather than something each screen remembers.
  Stream<List<AttendanceEntry>> watchRoster({
    required String batchId,
    required String date,
    required AttendanceSession session,
  });

  /// Pulls the server's copy into the mirror. Failures are returned, not
  /// thrown — a roster with no network still renders from cache.
  Future<Result<void>> refreshRoster({
    required String batchId,
    required String date,
    required AttendanceSession session,
  });

  /// Records a mark.
  ///
  /// Commits locally and queues the request. Returns as soon as the local write
  /// lands, which is what makes the roster usable in a hall with no signal.
  Future<Result<void>> mark({
    required String batchId,
    required String enrollmentId,
    required String date,
    required AttendanceSession session,
    required AttendanceStatus status,
    int? minutesLate,
    String? remark,
  });

  /// Every correction ever made to one student on one date, oldest first.
  ///
  /// A product feature: a guardian disputing a mark is shown what changed.
  Future<Result<List<AttendanceEntry>>> history({
    required String enrollmentId,
    required String date,
  });
}
