import 'package:flutter/foundation.dart';

/// How a student was recorded for one session.
enum AttendanceStatus {
  present,
  absent,
  late,
  excused;

  static AttendanceStatus fromName(String? name) {
    return AttendanceStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => AttendanceStatus.absent,
    );
  }

  String get label => switch (this) {
    AttendanceStatus.present => 'Present',
    AttendanceStatus.absent => 'Absent',
    AttendanceStatus.late => 'Late',
    AttendanceStatus.excused => 'Excused',
  };
}

/// One roll-call: a class, on a date, for a period.
@immutable
class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.classId,
    required this.className,
    required this.date,
    required this.period,
    required this.markedCount,
    required this.studentCount,
    this.isFinalised = false,
  });

  final String id;
  final String classId;
  final String className;
  final DateTime date;
  final String period;
  final int markedCount;
  final int studentCount;

  /// Once the office finalises a session it can only be changed by someone
  /// holding `attendance:amend`.
  final bool isFinalised;

  bool get isComplete => studentCount > 0 && markedCount >= studentCount;

  double get completion => studentCount == 0 ? 0 : (markedCount / studentCount).clamp(0.0, 1.0);
}

/// One student's status within a session.
@immutable
class AttendanceMark {
  const AttendanceMark({
    required this.studentId,
    required this.studentName,
    required this.status,
    this.note,
    this.isPending = false,
  });

  final String studentId;
  final String studentName;
  final AttendanceStatus status;
  final String? note;

  /// True while the change is sitting in the outbox. The roster shows these
  /// with a "will send" marker so a teacher can tell saved-locally from
  /// saved-for-real.
  final bool isPending;

  AttendanceMark copyWith({
    AttendanceStatus? status,
    String? note,
    bool? isPending,
  }) {
    return AttendanceMark(
      studentId: studentId,
      studentName: studentName,
      status: status ?? this.status,
      note: note ?? this.note,
      isPending: isPending ?? this.isPending,
    );
  }
}
