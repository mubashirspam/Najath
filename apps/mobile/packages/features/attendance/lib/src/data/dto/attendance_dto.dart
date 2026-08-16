/// Wire shape of one attendance mark.
///
/// Separate from the entity so a backend field rename is absorbed here and
/// nothing above the data layer changes.
class AttendanceMarkDto {
  const AttendanceMarkDto({
    required this.id,
    required this.enrollmentId,
    required this.attendanceDate,
    required this.session,
    required this.status,
    required this.markedAt,
    this.studentId,
    this.studentName,
    this.rollNo,
    this.minutesLate,
    this.remark,
    this.markedBy,
    this.supersedesId,
    this.isCurrent = true,
  });

  factory AttendanceMarkDto.fromJson(Map<String, dynamic> json) {
    return AttendanceMarkDto(
      id: json['id']?.toString() ?? '',
      enrollmentId: json['enrollmentId']?.toString() ?? '',
      attendanceDate: json['date']?.toString() ?? '',
      session: json['session']?.toString() ?? 'FULL_DAY',
      status: json['status']?.toString() ?? 'ABSENT',
      markedAt:
          DateTime.tryParse(json['markedAt']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc(),
      studentId: json['studentId']?.toString(),
      studentName: json['studentName']?.toString(),
      rollNo: json['rollNo']?.toString(),
      minutesLate: (json['minutesLate'] as num?)?.toInt(),
      remark: json['remark']?.toString(),
      markedBy: json['markedBy']?.toString(),
      supersedesId: json['supersedesId']?.toString(),
      isCurrent: json['isCurrent'] != false,
    );
  }

  final String id;
  final String enrollmentId;

  /// `YYYY-MM-DD` in Asia/Kolkata. A calendar fact, never derived from a UTC
  /// instant.
  final String attendanceDate;

  final String session;
  final String status;
  final DateTime markedAt;
  final String? studentId;
  final String? studentName;
  final String? rollNo;
  final int? minutesLate;
  final String? remark;
  final String? markedBy;
  final String? supersedesId;
  final bool isCurrent;

  /// The body sent to `POST /attendance/batch`.
  ///
  /// Carries the client-generated id: the server accepts it, so a replay writes
  /// the same row rather than a duplicate.
  Map<String, dynamic> toJson() => {
    'clientId': id,
    'enrollmentId': enrollmentId,
    'date': attendanceDate,
    'session': session,
    'status': status,
    'minutesLate': minutesLate,
    'remark': remark,
  };
}
