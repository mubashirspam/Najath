import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database.dart';
import '../tables.dart';

part 'attendance_dao.g.dart';

/// One student on a roster, already joined.
///
/// This is the shape the roster screen needs, and it comes out of SQLite in one
/// query. Against a key-value cache it would be a scan of every mark plus a
/// scan of every enrollment plus a manual join in Dart — which is the whole
/// argument for a relational mirror.
class RosterRow {
  const RosterRow({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    required this.rollNo,
    this.record,
  });

  final String enrollmentId;
  final String studentId;
  final String studentName;
  final String? rollNo;

  /// Null when this student has not been marked yet today.
  final AttendanceRecord? record;

  bool get isMarked => record != null;
}

@DriftAccessor(
  tables: [AttendanceRecords, Enrollments, Students],
)
class AttendanceDao extends DatabaseAccessor<AppDatabase> with _$AttendanceDaoMixin {
  AttendanceDao(super.attachedDatabase);

  /// The roster for one batch on one date: every active enrollment, left-joined
  /// to its current mark.
  ///
  /// A left join, not an inner one — an unmarked student must still appear, and
  /// appear in roll order, because the fast path is "mark only the absentees".
  Stream<List<RosterRow>> watchBatchRoster({
    required String batchId,
    required String date,
    required String session,
  }) {
    final query =
        select(enrollments).join([
            innerJoin(students, students.id.equalsExp(enrollments.studentId)),
            leftOuterJoin(
              attendanceRecords,
              attendanceRecords.enrollmentId.equalsExp(enrollments.id) &
                  attendanceRecords.attendanceDate.equals(date) &
                  attendanceRecords.session.equals(session) &
                  attendanceRecords.isCurrent.equals(true),
            ),
          ])
          ..where(enrollments.batchId.equals(batchId) & enrollments.status.equals('active'))
          ..orderBy([
            OrderingTerm.asc(enrollments.rollNo),
            OrderingTerm.asc(students.fullName),
          ]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => RosterRow(
              enrollmentId: row.readTable(enrollments).id,
              studentId: row.readTable(students).id,
              studentName: row.readTable(students).fullName,
              rollNo: row.readTable(enrollments).rollNo,
              record: row.readTableOrNull(attendanceRecords),
            ),
          )
          .toList(),
    );
  }

  Future<int> countMarked({
    required String batchId,
    required String date,
    required String session,
  }) async {
    final countExp = attendanceRecords.id.count();
    final query =
        selectOnly(attendanceRecords).join([
            innerJoin(
              enrollments,
              enrollments.id.equalsExp(attendanceRecords.enrollmentId),
            ),
          ])
          ..addColumns([countExp])
          ..where(
            enrollments.batchId.equals(batchId) &
                attendanceRecords.attendanceDate.equals(date) &
                attendanceRecords.session.equals(session) &
                attendanceRecords.isCurrent.equals(true),
          );

    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  /// One student's marks over a range, current rows only.
  Future<List<AttendanceRecord>> forEnrollment({
    required String enrollmentId,
    required String from,
    required String to,
  }) {
    return (select(attendanceRecords)
          ..where(
            (t) =>
                t.enrollmentId.equals(enrollmentId) &
                t.isCurrent.equals(true) &
                t.attendanceDate.isBiggerOrEqualValue(from) &
                t.attendanceDate.isSmallerOrEqualValue(to),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.attendanceDate)]))
        .get();
  }

  /// The full history for one student on one date, superseded rows included.
  ///
  /// A product feature, not a debugging tool: a guardian disputing a mark is
  /// shown that it was corrected, by whom, and when.
  Future<List<AttendanceRecord>> historyFor({
    required String enrollmentId,
    required String date,
  }) {
    return (select(attendanceRecords)
          ..where((t) => t.enrollmentId.equals(enrollmentId) & t.attendanceDate.equals(date))
          ..orderBy([(t) => OrderingTerm.asc(t.markedAt)]))
        .get();
  }

  /// Commits a mark locally, ahead of the server.
  ///
  /// Append-only, exactly as on the server: a correction inserts a new row
  /// carrying `supersedesId` and flips `isCurrent` on the old one, in one
  /// transaction. Half of that applied is a corrupt record.
  Future<void> upsertMark(AttendanceRecordsCompanion record) async {
    await transaction(() async {
      final existing =
          await (select(attendanceRecords)..where(
                (t) =>
                    t.enrollmentId.equals(record.enrollmentId.value) &
                    t.attendanceDate.equals(record.attendanceDate.value) &
                    t.session.equals(record.session.value) &
                    t.isCurrent.equals(true),
              ))
              .getSingleOrNull();

      if (existing != null) {
        await (update(attendanceRecords)..where((t) => t.id.equals(existing.id))).write(
          const AttendanceRecordsCompanion(isCurrent: Value(false)),
        );
      }

      await into(attendanceRecords).insertOnConflictUpdate(
        record.copyWith(
          supersedesId: Value(existing?.id),
          isCurrent: const Value(true),
        ),
      );
    });
  }

  /// Applies the server's view of a roster without clobbering unsent work.
  ///
  /// A row still flagged pending is the teacher's correction; the server's copy
  /// of it is older by definition, so it is skipped rather than overwritten.
  Future<void> mergeFromServer(List<AttendanceRecordsCompanion> incoming) async {
    if (incoming.isEmpty) return;

    final pending = await (select(attendanceRecords)..where((t) => t.isPending.equals(true))).get();
    final pendingIds = pending.map((r) => r.id).toSet();

    final safe = incoming.where((r) => !pendingIds.contains(r.id.value)).toList();
    if (safe.isEmpty) return;

    await batch((b) => b.insertAllOnConflictUpdate(attendanceRecords, safe));
  }

  Future<void> clearPendingFlag(String id) {
    return (update(attendanceRecords)..where((t) => t.id.equals(id))).write(
      const AttendanceRecordsCompanion(isPending: Value(false)),
    );
  }
}

final attendanceDaoProvider = Provider<AttendanceDao>((ref) {
  return AttendanceDao(ref.watch(appDatabaseProvider));
});
