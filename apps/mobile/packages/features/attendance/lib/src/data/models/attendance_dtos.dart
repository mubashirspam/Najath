import '../../domain/entities/attendance.dart';

class AttendanceSessionDto {
  const AttendanceSessionDto({
    required this.id,
    required this.classId,
    required this.className,
    required this.date,
    required this.period,
    required this.markedCount,
    required this.studentCount,
    required this.isFinalised,
  });

  factory AttendanceSessionDto.fromJson(Map<String, dynamic> json) {
    return AttendanceSessionDto(
      id: json['id']?.toString() ?? '',
      classId: json['classId']?.toString() ?? '',
      className: json['className']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      period: json['period']?.toString() ?? '',
      markedCount: (json['markedCount'] as num?)?.toInt() ?? 0,
      studentCount: (json['studentCount'] as num?)?.toInt() ?? 0,
      isFinalised: json['isFinalised'] == true,
    );
  }

  final String id;
  final String classId;
  final String className;
  final DateTime date;
  final String period;
  final int markedCount;
  final int studentCount;
  final bool isFinalised;

  Map<String, dynamic> toJson() => {
    'id': id,
    'classId': classId,
    'className': className,
    'date': date.toIso8601String(),
    'period': period,
    'markedCount': markedCount,
    'studentCount': studentCount,
    'isFinalised': isFinalised,
  };

  AttendanceSession toEntity() => AttendanceSession(
    id: id,
    classId: classId,
    className: className,
    date: date,
    period: period,
    markedCount: markedCount,
    studentCount: studentCount,
    isFinalised: isFinalised,
  );
}

class AttendanceMarkDto {
  const AttendanceMarkDto({
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.status,
    this.note,
  });

  factory AttendanceMarkDto.fromJson(Map<String, dynamic> json) {
    return AttendanceMarkDto(
      sessionId: json['sessionId']?.toString() ?? '',
      studentId: json['studentId']?.toString() ?? '',
      studentName: json['studentName']?.toString() ?? '',
      status: json['status']?.toString() ?? AttendanceStatus.absent.name,
      note: json['note']?.toString(),
    );
  }

  final String sessionId;
  final String studentId;
  final String studentName;
  final String status;
  final String? note;

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'studentId': studentId,
    'studentName': studentName,
    'status': status,
    'note': note,
  };

  AttendanceMark toEntity({bool isPending = false}) => AttendanceMark(
    studentId: studentId,
    studentName: studentName,
    status: AttendanceStatus.fromName(status),
    note: note,
    isPending: isPending,
  );
}
