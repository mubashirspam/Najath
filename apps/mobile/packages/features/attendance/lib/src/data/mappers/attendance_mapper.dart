import 'package:najath_local_db/najath_local_db.dart';

import '../../domain/entities/attendance.dart';
import '../dto/attendance_dto.dart';

/// DTO ↔ drift row ↔ entity. The only place the three shapes meet.
class AttendanceMapper {
  AttendanceMapper._();

  /// A joined roster row becomes the entity the screen renders.
  ///
  /// An unmarked student defaults to `PRESENT`: the fast path is marking only
  /// the absentees, so the default must be the common case. `isMarked` is what
  /// distinguishes "nobody has looked at this student" from "someone marked
  /// them present".
  static AttendanceEntry fromRosterRow(RosterRow row, {required bool isPending}) {
    final record = row.record;
    return AttendanceEntry(
      enrollmentId: row.enrollmentId,
      studentId: row.studentId,
      studentName: row.studentName,
      rollNo: row.rollNo,
      status: record == null ? AttendanceStatus.present : AttendanceStatus.fromWire(record.status),
      minutesLate: record?.minutesLate,
      remark: record?.remark,
      isMarked: record != null,
      isPending: isPending,
      isCorrection: record?.supersedesId != null,
    );
  }

  static AttendanceEntry fromRecord(
    AttendanceRecord record, {
    required String studentName,
    required String studentId,
  }) {
    return AttendanceEntry(
      enrollmentId: record.enrollmentId,
      studentId: studentId,
      studentName: studentName,
      status: AttendanceStatus.fromWire(record.status),
      minutesLate: record.minutesLate,
      remark: record.remark,
      isMarked: true,
      isCorrection: record.supersedesId != null,
    );
  }

  static AttendanceRecordsCompanion toCompanion(
    AttendanceMarkDto dto, {
    required bool isPending,
  }) {
    return AttendanceRecordsCompanion.insert(
      id: dto.id,
      enrollmentId: dto.enrollmentId,
      attendanceDate: dto.attendanceDate,
      session: dto.session,
      status: dto.status,
      markedAt: dto.markedAt,
      minutesLate: Value(dto.minutesLate),
      remark: Value(dto.remark),
      markedBy: Value(dto.markedBy),
      supersedesId: Value(dto.supersedesId),
      isCurrent: Value(dto.isCurrent),
      isPending: Value(isPending),
    );
  }
}
