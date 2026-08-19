import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:najath_local_db/najath_local_db.dart';
import 'package:path/path.dart' as p;

/// **The non-negotiable test** (`P0-TEST-01`).
///
/// From the spec: *"a teacher logs a full day for 3 batches with the network
/// disabled, kills the app, reopens, network returns → zero data loss, zero
/// duplicates."*
///
/// The device-level version is a `patrol` run on Firebase Test Lab. This is the
/// deterministic half — everything below the widget layer — so it runs on every
/// PR in seconds rather than only nightly. It is also the half where the bugs
/// live: the outbox, the mirror, and what survives a process death.
///
/// The database is **file-backed on purpose**. An in-memory one vanishes on
/// `close()`, which would make "the app was killed" untestable — the very thing
/// this is here to prove.
void main() {
  late Directory tempDir;
  late String dbPath;
  late AppDatabase db;
  late AttendanceDao attendance;
  late RosterDao roster;
  late OutboxStore outbox;

  const date = '2026-08-19';
  const session = 'FULL_DAY';
  const batches = ['batch-1', 'batch-2', 'batch-3'];
  const studentsPerBatch = 22;

  void attach() {
    db = AppDatabase(NativeDatabase(File(dbPath)));
    attendance = AttendanceDao(db);
    roster = RosterDao(db);
    outbox = OutboxStore(db);
  }

  /// What the OS does to a backgrounded app: every Dart object referencing the
  /// connection goes away, and only what reached the file survives.
  Future<void> killAndReopen() async {
    await db.close();
    attach();
  }

  Future<void> seedInstitution() async {
    await roster.upsertDepartments([
      DepartmentsCompanion.insert(
        id: 'dept-hifz',
        code: 'HIFZ',
        name: 'Hifz & Doura',
        kind: 'HIFZ_DOURA',
      ),
    ]);
    await roster.upsertBatches([
      for (final id in batches)
        BatchesCompanion.insert(id: id, departmentId: 'dept-hifz', name: id),
    ]);
    await roster.upsertStudents([
      for (final batch in batches)
        for (var i = 1; i <= studentsPerBatch; i++)
          StudentsCompanion.insert(
            id: '$batch-s$i',
            admissionNo: '$batch-$i',
            fullName: 'Student $i of $batch',
          ),
    ]);
    await roster.upsertEnrollments([
      for (final batch in batches)
        for (var i = 1; i <= studentsPerBatch; i++)
          EnrollmentsCompanion.insert(
            id: '$batch-e$i',
            studentId: '$batch-s$i',
            departmentId: 'dept-hifz',
            batchId: Value(batch),
            rollNo: Value('$i'),
          ),
    ]);
  }

  /// One mark: committed locally, then queued. The repository's write path
  /// reduced to the two operations that matter.
  Future<void> mark(String enrollmentId, String status, {required String id}) async {
    await attendance.upsertMark(
      AttendanceRecordsCompanion.insert(
        id: id,
        enrollmentId: enrollmentId,
        attendanceDate: date,
        session: session,
        status: status,
        markedAt: DateTime.now().toUtc(),
        isPending: const Value(true),
      ),
    );
    await outbox.enqueue(
      id: id,
      entity: 'attendance',
      operation: 'create',
      endpoint: '/attendance/batch',
      // The natural key, not the row id — a correction dedupes against the
      // original instead of queueing a second request.
      idempotencyKey: 'attendance:$enrollmentId:$date:$session',
      payload: {'enrollmentId': enrollmentId, 'status': status},
      label: status,
    );
  }

  /// Marks every student in every batch, the way a day actually goes.
  Future<int> logFullDay() async {
    var written = 0;
    for (final batch in batches) {
      for (var i = 1; i <= studentsPerBatch; i++) {
        final status = i % 11 == 0
            ? 'ABSENT'
            : i % 7 == 0
            ? 'LATE'
            : 'PRESENT';
        await mark('$batch-e$i', status, id: '$batch-m$i');
        written++;
      }
    }
    return written;
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('najath_replay');
    dbPath = p.join(tempDir.path, 'najath.sqlite');
    attach();
    await seedInstitution();
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('a full day survives being killed and reopened — no loss, no duplicates', () async {
    final written = await logFullDay();
    expect(written, batches.length * studentsPerBatch);

    await killAndReopen();

    // Zero loss: every mark is still queued, and still on its roster.
    expect(await outbox.pendingCount(), written);

    // Zero duplicates: exactly one queued entry per student.
    final queued = await outbox.dueFor('attendance', limit: 500);
    expect(queued, hasLength(written));
    expect(queued.map((w) => w.idempotencyKey).toSet(), hasLength(written));

    for (final batch in batches) {
      final rows = await attendance
          .watchBatchRoster(batchId: batch, date: date, session: session)
          .first;
      expect(rows, hasLength(studentsPerBatch));
      expect(rows.every((r) => r.isMarked), isTrue, reason: '$batch has a gap');
      expect(rows.every((r) => r.record!.isPending), isTrue);
    }
  });

  test('draining after the restart leaves nothing behind', () async {
    final written = await logFullDay();
    await killAndReopen();

    // The engine's success path, applied to every queued write.
    for (final write in await outbox.dueFor('attendance', limit: 500)) {
      await outbox.markSent(write.id);
      await attendance.clearPendingFlag(write.id);
    }

    expect(await outbox.pendingCount(), 0);

    for (final batch in batches) {
      final rows = await attendance
          .watchBatchRoster(batchId: batch, date: date, session: session)
          .first;
      expect(rows.every((r) => r.isMarked), isTrue);
      expect(
        rows.every((r) => !r.record!.isPending),
        isTrue,
        reason: 'a sent mark must stop showing "will send"',
      );
    }

    // And the marks themselves are still there — draining sends work, it does
    // not consume it.
    final all = await db.select(db.attendanceRecords).get();
    expect(all, hasLength(written));
  });

  test('corrections collapse to one request carrying the last answer', () async {
    // Each correction is a new row — that is what makes the record a ledger —
    // so the outbox has to dedupe on the natural key, not the row id.
    var revision = 0;
    for (final status in ['PRESENT', 'ABSENT', 'LATE']) {
      await mark('batch-1-e1', status, id: 'batch-1-m1-r${++revision}');
    }
    await killAndReopen();

    final queued = await outbox.dueFor('attendance');
    expect(queued, hasLength(1));
    expect(queued.single.payload['status'], 'LATE');

    // The mirror keeps the whole trail, because the record is a ledger.
    final history = await attendance.historyFor(
      enrollmentId: 'batch-1-e1',
      date: date,
    );
    expect(history, hasLength(3));
    expect(history.where((r) => r.isCurrent), hasLength(1));
  });

  test('a retry after a lost response creates no duplicate', () async {
    await mark('batch-1-e1', 'PRESENT', id: 'batch-1-m1');
    final key = (await outbox.dueFor('attendance')).single.idempotencyKey;

    // The request committed but the response never arrived, so the teacher
    // marks again. A new row id, the same natural key.
    await mark('batch-1-e1', 'PRESENT', id: 'batch-1-m1-r2');

    final queued = await outbox.dueFor('attendance');
    expect(queued, hasLength(1));
    expect(queued.single.idempotencyKey, key);

    final rows = await attendance
        .watchBatchRoster(batchId: 'batch-1', date: date, session: session)
        .first;
    expect(rows.where((r) => r.isMarked), hasLength(1));
  });

  test('a mid-day refresh does not overwrite unsent work', () async {
    await mark('batch-1-e1', 'ABSENT', id: 'batch-1-m1');

    // Sync pulls the server's older copy while the correction is still queued.
    await attendance.mergeFromServer([
      AttendanceRecordsCompanion.insert(
        id: 'batch-1-m1',
        enrollmentId: 'batch-1-e1',
        attendanceDate: date,
        session: session,
        status: 'PRESENT',
        markedAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      ),
    ]);

    final rows = await attendance
        .watchBatchRoster(batchId: 'batch-1', date: date, session: session)
        .first;
    expect(
      rows.firstWhere((r) => r.enrollmentId == 'batch-1-e1').record!.status,
      'ABSENT',
      reason: "the teacher's unsent correction is newer than the server's copy",
    );
  });

  test('launch pruning never reaches an unsent row', () async {
    await mark('batch-1-e1', 'PRESENT', id: 'batch-1-m1');
    await killAndReopen();

    // Pruning runs on launch. It must not touch work the server has not seen,
    // even work older than the retention window.
    await db.pruneOlderThan(0);

    expect(await outbox.pendingCount(), 1);
    final remaining = await db.select(db.attendanceRecords).get();
    expect(remaining.map((r) => r.id), contains('batch-1-m1'));
  });
}
