import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';

import '../../data/repositories/attendance_repository_impl.dart';
import '../../domain/entities/attendance.dart';

/// Sessions the signed-in user can see, cache-first.
class AttendanceSessionsNotifier extends AsyncNotifier<List<AttendanceSession>> {
  @override
  Future<List<AttendanceSession>> build() => _load();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _load(forceRefresh: true));
  }

  Future<List<AttendanceSession>> _load({bool forceRefresh = false}) async {
    final result = await ref
        .read(attendanceRepositoryProvider)
        .sessions(forceRefresh: forceRefresh);

    if (result.hasData) return result.data!;
    // `AsyncNotifier`'s failure channel is an exception, so the ApiError is
    // wrapped rather than converted to a message here — the view unwraps it and
    // decides how to render an offline miss versus a real failure.
    throw AppException(result.error!);
  }
}

final attendanceSessionsProvider =
    AsyncNotifierProvider<AttendanceSessionsNotifier, List<AttendanceSession>>(
      AttendanceSessionsNotifier.new,
    );

/// A session's roster.
///
/// A `StreamProvider` over the cache rather than a one-shot read: an optimistic
/// mark, a sync pass, or an outbox drain all repaint the open roster without
/// anyone remembering to invalidate.
final StreamProvider<List<AttendanceMark>> Function(String) attendanceMarksProvider =
    StreamProvider.family<List<AttendanceMark>, String>((ref, sessionId) {
      // Kick a fetch so a session opened for the first time fills in; the
      // stream below delivers the result when it lands in the cache.
      unawaited(ref.read(attendanceRepositoryProvider).marks(sessionId));
      return ref.read(attendanceRepositoryProvider).watchMarks(sessionId);
    });

/// Marks a student, optimistically.
///
/// Deliberately not an `AsyncNotifier` action: the write always succeeds
/// locally, so there is no pending state for the UI to render.
class MarkStudentAction {
  const MarkStudentAction(this._ref);

  final Ref _ref;

  Future<void> call({
    required String sessionId,
    required String studentId,
    required String studentName,
    required AttendanceStatus status,
    String? note,
  }) {
    return _ref
        .read(attendanceRepositoryProvider)
        .markStudent(
          sessionId: sessionId,
          studentId: studentId,
          studentName: studentName,
          status: status,
          note: note,
        );
  }
}

final markStudentActionProvider = Provider<MarkStudentAction>(
  MarkStudentAction.new,
);
