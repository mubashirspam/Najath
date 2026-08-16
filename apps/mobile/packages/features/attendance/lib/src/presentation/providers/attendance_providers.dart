import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';

import '../../data/repositories/attendance_repository_impl.dart';
import '../../domain/entities/attendance.dart';

/// Which roster is on screen.
///
/// A value type so the family key is stable — rebuilding it with the same
/// fields must not re-subscribe, or every frame would tear down the stream.
@immutable
class RosterKey {
  const RosterKey({
    required this.batchId,
    required this.date,
    this.session = AttendanceSession.fullDay,
  });

  final String batchId;
  final String date;
  final AttendanceSession session;

  @override
  bool operator ==(Object other) =>
      other is RosterKey &&
      other.batchId == batchId &&
      other.date == date &&
      other.session == session;

  @override
  int get hashCode => Object.hash(batchId, date, session);

  @override
  String toString() => 'RosterKey($batchId, $date, ${session.wire})';
}

/// The roster, streamed from the local database.
///
/// The UI never watches a network future. A refresh lands in SQLite and SQLite
/// pushes here, so the online and offline paths cannot diverge in behaviour —
/// one data path, offline-correct by construction.
final StreamProvider<List<AttendanceEntry>> Function(RosterKey) rosterProvider =
    StreamProvider.family<List<AttendanceEntry>, RosterKey>((ref, key) {
      final repository = ref.watch(attendanceRepositoryProvider);

      // Fill the mirror in the background; the stream below delivers whatever
      // arrives. A failure here is not fatal — the cached roster still renders,
      // which is the point.
      unawaited(
        repository.refreshRoster(
          batchId: key.batchId,
          date: key.date,
          session: key.session,
        ),
      );

      return repository.watchRoster(
        batchId: key.batchId,
        date: key.date,
        session: key.session,
      );
    });

/// Footer tallies, derived from the same stream rather than recomputed three
/// times in the widget tree on every frame.
final Provider<RosterTally> Function(RosterKey) rosterTallyProvider =
    Provider.family<RosterTally, RosterKey>((ref, key) {
      final entries = ref.watch(rosterProvider(key)).value ?? const [];
      return RosterTally.of(entries);
    });

/// Marks a student.
///
/// Deliberately not an `AsyncNotifier`: the write always succeeds locally, so
/// there is no pending state for the UI to render. What can fail is the
/// *send*, and that surfaces on the sync banner and the unsynced-work screen.
class MarkAttendance {
  const MarkAttendance(this._ref);

  final Ref _ref;

  Future<Result<void>> call({
    required RosterKey key,
    required String enrollmentId,
    required AttendanceStatus status,
    int? minutesLate,
    String? remark,
  }) {
    return _ref
        .read(attendanceRepositoryProvider)
        .mark(
          batchId: key.batchId,
          enrollmentId: enrollmentId,
          date: key.date,
          session: key.session,
          status: status,
          minutesLate: minutesLate,
          remark: remark,
        );
  }
}

final markAttendanceProvider = Provider<MarkAttendance>(MarkAttendance.new);
