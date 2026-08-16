import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:najath_local_db/najath_local_db.dart';

void main() {
  late AppDatabase db;
  late AttendanceDao attendance;
  late RosterDao roster;
  late OutboxStore outbox;
  late SyncCursorStore cursors;

  const date = '2026-08-16';
  const session = 'FULL_DAY';

  /// The minimum relational graph a roster needs: department → batch →
  /// students → enrollments.
  Future<void> seedBatch({int studentCount = 3}) async {
    await roster.upsertDepartments([
      DepartmentsCompanion.insert(
        id: 'dept-hifz',
        code: 'HIFZ',
        name: 'Hifz & Doura',
        kind: 'HIFZ_DOURA',
      ),
    ]);
    await roster.upsertBatches([
      BatchesCompanion.insert(id: 'batch-1', departmentId: 'dept-hifz', name: 'Batch 01'),
    ]);
    await roster.upsertStudents([
      for (var i = 1; i <= studentCount; i++)
        StudentsCompanion.insert(
          id: 'student-$i',
          admissionNo: 'ADM00$i',
          fullName: 'Student $i',
        ),
    ]);
    await roster.upsertEnrollments([
      for (var i = 1; i <= studentCount; i++)
        EnrollmentsCompanion.insert(
          id: 'enr-$i',
          studentId: 'student-$i',
          departmentId: 'dept-hifz',
          batchId: const Value('batch-1'),
          rollNo: Value('$i'),
        ),
    ]);
  }

  AttendanceRecordsCompanion mark(
    String enrollmentId,
    String status, {
    String? id,
    bool pending = true,
  }) => AttendanceRecordsCompanion.insert(
    id: id ?? 'mark-$enrollmentId',
    enrollmentId: enrollmentId,
    attendanceDate: date,
    session: session,
    status: status,
    markedAt: DateTime(2026, 8, 16, 9),
    isPending: Value(pending),
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    attendance = AttendanceDao(db);
    roster = RosterDao(db);
    outbox = OutboxStore(db);
    cursors = SyncCursorStore(db);
  });

  tearDown(() => db.close());

  group('roster — the join that justifies a relational mirror', () {
    test('every enrolled student appears, marked or not', () async {
      await seedBatch();
      await attendance.upsertMark(mark('enr-2', 'ABSENT'));

      final rows = await attendance
          .watchBatchRoster(batchId: 'batch-1', date: date, session: session)
          .first;

      expect(rows, hasLength(3));
      // The unmarked ones must still be listed — the fast path is "mark only
      // the absentees", which needs everyone on screen.
      expect(rows.where((r) => r.isMarked), hasLength(1));
      expect(rows.firstWhere((r) => r.enrollmentId == 'enr-2').record!.status, 'ABSENT');
    });

    test('roster comes back in roll order', () async {
      await seedBatch();

      final rows = await attendance
          .watchBatchRoster(batchId: 'batch-1', date: date, session: session)
          .first;

      expect(rows.map((r) => r.rollNo), ['1', '2', '3']);
    });

    test('a student from another batch is not on this roster', () async {
      await seedBatch();
      await roster.upsertBatches([
        BatchesCompanion.insert(id: 'batch-2', departmentId: 'dept-hifz', name: 'Batch 02'),
      ]);
      await roster.upsertStudents([
        StudentsCompanion.insert(id: 'other', admissionNo: 'ADM999', fullName: 'Other'),
      ]);
      await roster.upsertEnrollments([
        EnrollmentsCompanion.insert(
          id: 'enr-other',
          studentId: 'other',
          departmentId: 'dept-hifz',
          batchId: const Value('batch-2'),
        ),
      ]);

      final rows = await attendance
          .watchBatchRoster(batchId: 'batch-1', date: date, session: session)
          .first;

      expect(rows.map((r) => r.enrollmentId), isNot(contains('enr-other')));
    });

    test('batch summary counts only active enrollments', () async {
      await seedBatch();
      await roster.upsertEnrollments([
        EnrollmentsCompanion.insert(
          id: 'enr-left',
          studentId: 'student-1',
          departmentId: 'dept-hifz',
          batchId: const Value('batch-1'),
          status: const Value('transferred'),
        ),
      ]);

      final summaries = await roster.watchBatches().first;

      expect(summaries, hasLength(1));
      expect(summaries.single.studentCount, 3);
      expect(summaries.single.departmentName, 'Hifz & Doura');
    });

    test('a tombstoned enrollment leaves the roster', () async {
      await seedBatch();
      await roster.deleteEnrollments(['enr-2']);

      final rows = await attendance
          .watchBatchRoster(batchId: 'batch-1', date: date, session: session)
          .first;

      // Without tombstones a transferred-out student stays forever and gets
      // marked absent every day.
      expect(rows, hasLength(2));
    });
  });

  group('append-only corrections', () {
    test('a correction supersedes rather than overwriting', () async {
      await seedBatch();

      await attendance.upsertMark(mark('enr-1', 'ABSENT', id: 'mark-a'));
      await attendance.upsertMark(mark('enr-1', 'PRESENT', id: 'mark-b'));

      final history = await attendance.historyFor(enrollmentId: 'enr-1', date: date);
      expect(history, hasLength(2), reason: 'the original must survive');

      final current = history.where((r) => r.isCurrent).toList();
      expect(current, hasLength(1));
      expect(current.single.status, 'PRESENT');
      expect(current.single.supersedesId, 'mark-a');

      final superseded = history.firstWhere((r) => r.id == 'mark-a');
      expect(superseded.isCurrent, isFalse);
    });

    test('the roster shows only the current row', () async {
      await seedBatch();
      await attendance.upsertMark(mark('enr-1', 'ABSENT', id: 'mark-a'));
      await attendance.upsertMark(mark('enr-1', 'LATE', id: 'mark-b'));

      final rows = await attendance
          .watchBatchRoster(batchId: 'batch-1', date: date, session: session)
          .first;

      final row = rows.firstWhere((r) => r.enrollmentId == 'enr-1');
      expect(row.record!.status, 'LATE');
    });
  });

  group('server merge', () {
    test('does not clobber a mark still waiting to send', () async {
      await seedBatch();
      // The teacher corrected this offline; the server's copy is older.
      await attendance.upsertMark(mark('enr-1', 'PRESENT', id: 'm1'));

      await attendance.mergeFromServer([mark('enr-1', 'ABSENT', id: 'm1', pending: false)]);

      final rows = await attendance
          .watchBatchRoster(batchId: 'batch-1', date: date, session: session)
          .first;
      expect(rows.firstWhere((r) => r.enrollmentId == 'enr-1').record!.status, 'PRESENT');
    });

    test('overwrites a row that has already been sent', () async {
      await seedBatch();
      await attendance.upsertMark(mark('enr-1', 'PRESENT', id: 'm1', pending: false));

      await attendance.mergeFromServer([mark('enr-1', 'LATE', id: 'm1', pending: false)]);

      final rows = await attendance
          .watchBatchRoster(batchId: 'batch-1', date: date, session: session)
          .first;
      expect(rows.firstWhere((r) => r.enrollmentId == 'enr-1').record!.status, 'LATE');
    });
  });

  group('outbox', () {
    Future<void> queue(String id, {String entity = 'attendance'}) => outbox.enqueue(
      id: id,
      entity: entity,
      operation: 'create',
      endpoint: '/attendance/batch',
      payload: {'status': 'PRESENT'},
      idempotencyKey: 'key-$id',
      label: 'Student — Present',
    );

    test('queues and reports due work per entity', () async {
      await queue('m1');
      await queue('h1', entity: 'hifz_log');

      expect(await outbox.dueFor('attendance'), hasLength(1));
      expect(await outbox.dueFor('hifz_log'), hasLength(1));
      expect(await outbox.pendingEntities(), containsAll(['attendance', 'hifz_log']));
      expect(await outbox.pendingCount(), 2);
    });

    test('re-queuing the same record replaces it, latest wins', () async {
      // Three offline taps on the same student must send one request carrying
      // the final answer.
      for (final status in ['PRESENT', 'LATE', 'ABSENT']) {
        await outbox.enqueue(
          id: 'm1',
          entity: 'attendance',
          operation: 'create',
          endpoint: '/attendance/batch',
          payload: {'status': status},
          idempotencyKey: 'key-m1',
        );
      }

      final due = await outbox.dueFor('attendance');
      expect(due, hasLength(1));
      expect(due.single.payload['status'], 'ABSENT');
    });

    test('a retryable failure backs off and stays queued', () async {
      await queue('m1');
      await outbox.markRetryable('m1', 'network', 0);

      expect(await outbox.pendingCount(), 1);
      expect(await outbox.dueFor('attendance'), isEmpty);
    });

    test('a blocked entry stops retrying but stays visible', () async {
      await queue('m1');
      await outbox.markBlocked('m1', 'FORBIDDEN');

      expect(await outbox.dueFor('attendance'), isEmpty);
      expect(await outbox.pendingCount(), 0);

      final all = await outbox.watchAll().first;
      expect(all, hasLength(1));
      expect(all.single.isBlocked, isTrue);
      expect(all.single.lastError, 'FORBIDDEN');
    });

    test('pendingIds drives the per-row will-send marker', () async {
      await queue('m1');
      expect(await outbox.pendingIds('attendance'), {'m1'});

      await outbox.markSent('m1');
      expect(await outbox.pendingIds('attendance'), isEmpty);
    });
  });

  group('sync cursors', () {
    test('round-trips the server time, not local time', () async {
      final serverTime = DateTime.utc(2026, 8, 16, 4, 30);
      await cursors.setCursor('students', serverTime);

      expect(await cursors.lastPulled('students'), serverTime);
      // A device clock minutes fast would silently skip rows, so the cursor is
      // always what the server said.
      expect(await cursors.lastPulled('batches'), isNull);
    });

    test('one-time task markers survive until the cache is cleared', () async {
      expect(await cursors.isDone('quran.index'), isFalse);
      await cursors.markDone('quran.index');
      expect(await cursors.isDone('quran.index'), isTrue);

      await db.clearCachedData();
      expect(await cursors.isDone('quran.index'), isFalse);
    });
  });

  group('retention and clearing', () {
    test('clearing the cache keeps unsent work', () async {
      await seedBatch();
      await attendance.upsertMark(mark('enr-1', 'PRESENT'));
      await outbox.enqueue(
        id: 'm1',
        entity: 'attendance',
        operation: 'create',
        endpoint: '/x',
        payload: const {},
        idempotencyKey: 'k',
      );

      await db.clearCachedData();

      expect(await roster.student('student-1'), isNull);
      // The outbox is the user's work, not ours to discard.
      expect(await outbox.pendingCount(), 1);
    });

    test('pruning spares rows that have not been sent', () async {
      await seedBatch();
      await attendance.upsertMark(
        AttendanceRecordsCompanion.insert(
          id: 'old-sent',
          enrollmentId: 'enr-1',
          attendanceDate: '2020-01-01',
          session: session,
          status: 'PRESENT',
          markedAt: DateTime(2020),
        ),
      );
      await attendance.upsertMark(
        AttendanceRecordsCompanion.insert(
          id: 'old-pending',
          enrollmentId: 'enr-2',
          attendanceDate: '2020-01-01',
          session: session,
          status: 'PRESENT',
          markedAt: DateTime(2020),
          isPending: const Value(true),
        ),
      );

      await db.pruneOlderThan(60);

      final remaining = await db.select(db.attendanceRecords).get();
      expect(remaining.map((r) => r.id), ['old-pending']);
    });

    test('sign-out wipes everything including the queue', () async {
      await seedBatch();
      await outbox.enqueue(
        id: 'm1',
        entity: 'attendance',
        operation: 'create',
        endpoint: '/x',
        payload: const {},
        idempotencyKey: 'k',
      );

      await db.wipe();

      // A new principal must never inherit the previous one's queued writes.
      expect(await outbox.pendingCount(), 0);
      expect(await roster.watchBatches().first, isEmpty);
    });
  });
}
