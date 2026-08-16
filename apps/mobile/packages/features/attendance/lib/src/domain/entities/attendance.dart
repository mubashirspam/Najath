import 'package:flutter/foundation.dart';

/// How a student was recorded for one session.
enum AttendanceStatus {
  present('PRESENT'),
  absent('ABSENT'),
  late('LATE'),
  leave('LEAVE'),
  halfDay('HALF_DAY'),
  excused('EXCUSED');

  const AttendanceStatus(this.wire);

  final String wire;

  static AttendanceStatus fromWire(String? wire) => AttendanceStatus.values.firstWhere(
    (s) => s.wire == wire,
    orElse: () => AttendanceStatus.absent,
  );

  /// The four a teacher toggles between on a roster. `LEAVE` is applied by the
  /// leave module and `HALF_DAY` is derived from a late threshold, so neither
  /// is a button.
  static const List<AttendanceStatus> markable = [
    AttendanceStatus.present,
    AttendanceStatus.late,
    AttendanceStatus.absent,
    AttendanceStatus.excused,
  ];

  /// Counts toward the numerator of the attendance percentage. The percentage
  /// itself is computed server-side — this only decides chip colour.
  bool get isCredited => this == present || this == late || this == excused || this == leave;
}

/// Which part of the day a mark covers. Set by the department's attendance
/// mode, not chosen per student.
enum AttendanceSession {
  fullDay('FULL_DAY'),
  forenoon('FORENOON'),
  afternoon('AFTERNOON'),
  period('PERIOD');

  const AttendanceSession(this.wire);

  final String wire;

  static AttendanceSession fromWire(String? wire) => AttendanceSession.values.firstWhere(
    (s) => s.wire == wire,
    orElse: () => AttendanceSession.fullDay,
  );
}

/// One student's row on a roster.
///
/// Enrollment-scoped, not student-scoped: a student in Hifz and General
/// Education is marked twice a day and the two are unrelated.
@immutable
class AttendanceEntry {
  const AttendanceEntry({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    required this.status,
    this.rollNo,
    this.minutesLate,
    this.remark,
    this.isMarked = false,
    this.isPending = false,
    this.isCorrection = false,
  });

  final String enrollmentId;
  final String studentId;
  final String studentName;
  final String? rollNo;

  /// Defaults to [AttendanceStatus.present] for an unmarked student — the fast
  /// path is marking only the absentees.
  final AttendanceStatus status;

  final int? minutesLate;
  final String? remark;

  /// False until a mark exists. Drives the "N of M marked" counter.
  final bool isMarked;

  /// True while the mark is still in the outbox. The roster shows this so a
  /// teacher can tell saved-here from saved-on-the-server.
  final bool isPending;

  /// This row supersedes an earlier mark for the same session.
  final bool isCorrection;

  AttendanceEntry copyWith({
    AttendanceStatus? status,
    int? minutesLate,
    String? remark,
    bool? isMarked,
    bool? isPending,
  }) {
    return AttendanceEntry(
      enrollmentId: enrollmentId,
      studentId: studentId,
      studentName: studentName,
      rollNo: rollNo,
      status: status ?? this.status,
      minutesLate: minutesLate ?? this.minutesLate,
      remark: remark ?? this.remark,
      isMarked: isMarked ?? this.isMarked,
      isPending: isPending ?? this.isPending,
      isCorrection: isCorrection,
    );
  }
}

/// The tallies the sticky footer shows, computed once per rebuild rather than
/// three times in the widget tree.
@immutable
class RosterTally {
  const RosterTally({
    required this.present,
    required this.absent,
    required this.late,
    required this.marked,
    required this.total,
  });

  factory RosterTally.of(List<AttendanceEntry> entries) {
    var present = 0;
    var absent = 0;
    var late = 0;
    var marked = 0;

    for (final entry in entries) {
      if (entry.isMarked) marked++;
      switch (entry.status) {
        case AttendanceStatus.present:
        case AttendanceStatus.excused:
        case AttendanceStatus.leave:
          present++;
        case AttendanceStatus.late:
          late++;
        case AttendanceStatus.absent:
        case AttendanceStatus.halfDay:
          absent++;
      }
    }

    return RosterTally(
      present: present,
      absent: absent,
      late: late,
      marked: marked,
      total: entries.length,
    );
  }

  final int present;
  final int absent;
  final int late;
  final int marked;
  final int total;

  bool get isComplete => total > 0 && marked >= total;
}
