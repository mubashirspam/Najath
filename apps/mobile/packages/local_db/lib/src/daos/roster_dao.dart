import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database.dart';
import '../tables.dart';

part 'roster_dao.g.dart';

/// A batch with the counts a teacher's list needs, resolved in one query.
class BatchSummary {
  const BatchSummary({
    required this.batch,
    required this.departmentName,
    required this.studentCount,
  });

  final BatchRow batch;
  final String departmentName;
  final int studentCount;
}

/// Master data: departments, batches, classes, students and their enrollments.
///
/// Written by the sync engine, read by every feature. Nothing here is
/// teacher-authored, so it is plain server-wins — a conflict is not possible.
@DriftAccessor(
  tables: [Students, Departments, Batches, ClassSections, Enrollments],
)
class RosterDao extends DatabaseAccessor<AppDatabase> with _$RosterDaoMixin {
  RosterDao(super.attachedDatabase);

  /// Every batch with its department and its active headcount.
  ///
  /// Raw SQL because this is a GROUP BY with an aggregate over a left join, and
  /// drift's typed builder cannot express the result row without contortion.
  /// `watch` still re-emits when any of the three tables changes.
  Stream<List<BatchSummary>> watchBatches() {
    return customSelect(
      '''
      SELECT b.*, d.name AS department_name, COUNT(e.id) AS student_count
      FROM batches b
      JOIN departments d ON d.id = b.department_id
      LEFT JOIN enrollments e ON e.batch_id = b.id AND e.status = 'active'
      GROUP BY b.id, d.name
      ORDER BY b.name
      ''',
      readsFrom: {batches, departments, enrollments},
    ).watch().map(
      (rows) => rows
          .map(
            (row) => BatchSummary(
              batch: batches.map(row.data),
              departmentName: row.read<String>('department_name'),
              studentCount: row.read<int>('student_count'),
            ),
          )
          .toList(),
    );
  }

  Future<Enrollment?> enrollmentFor({
    required String studentId,
    required String departmentId,
  }) {
    return (select(enrollments)..where(
          (t) => t.studentId.equals(studentId) & t.departmentId.equals(departmentId),
        ))
        .getSingleOrNull();
  }

  /// Every enrollment a guardian's ward holds. A student in Hifz and General
  /// Education has two, and their attendance differs.
  Future<List<Enrollment>> enrollmentsForStudent(String studentId) {
    return (select(enrollments)..where((t) => t.studentId.equals(studentId))).get();
  }

  Future<Student?> student(String id) {
    return (select(students)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertStudents(List<StudentsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(students, rows));

  Future<void> upsertDepartments(List<DepartmentsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(departments, rows));

  Future<void> upsertBatches(List<BatchesCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(batches, rows));

  Future<void> upsertClassSections(List<ClassSectionsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(classSections, rows));

  Future<void> upsertEnrollments(List<EnrollmentsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(enrollments, rows));

  /// Applies tombstones from a delta pull.
  ///
  /// Not optional: without it a student transferred out stays on the teacher's
  /// roster forever, and gets marked absent every day.
  Future<void> deleteEnrollments(List<String> ids) {
    if (ids.isEmpty) return Future.value();
    return (delete(enrollments)..where((t) => t.id.isIn(ids))).go();
  }

  Future<void> deleteStudents(List<String> ids) {
    if (ids.isEmpty) return Future.value();
    return (delete(students)..where((t) => t.id.isIn(ids))).go();
  }
}

final rosterDaoProvider = Provider<RosterDao>((ref) {
  return RosterDao(ref.watch(appDatabaseProvider));
});
