import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:najath_local_db/najath_local_db.dart';

void main() {
  late AppDatabase db;
  late OutboxStore outbox;
  late CacheStore cache;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    outbox = OutboxStore(db);
    cache = CacheStore(db);
  });

  tearDown(() => db.close());

  group('OutboxStore', () {
    test('queues a write and reports it as due', () async {
      await outbox.enqueue(
        endpoint: '/attendance/sessions/s1/marks',
        method: 'POST',
        payload: {'studentId': 'st1', 'status': 'present'},
        module: 'attendance',
      );

      final due = await outbox.due();
      expect(due, hasLength(1));
      expect(due.first.payload['status'], 'present');
      expect(await outbox.pendingCount(), 1);
    });

    test('collapses repeated edits of the same target, latest wins', () async {
      // The offline correction case: a teacher taps present, then late, then
      // absent with no signal. One request must reach the server, carrying the
      // final answer.
      for (final status in ['present', 'late', 'absent']) {
        await outbox.enqueue(
          endpoint: '/attendance/sessions/s1/marks',
          method: 'POST',
          payload: {'studentId': 'st1', 'status': status},
          module: 'attendance',
          dedupeKey: 'attendance:s1:st1',
        );
      }

      final due = await outbox.due();
      expect(due, hasLength(1));
      expect(due.first.payload['status'], 'absent');
    });

    test('keeps separate students separate', () async {
      for (final student in ['st1', 'st2']) {
        await outbox.enqueue(
          endpoint: '/attendance/sessions/s1/marks',
          method: 'POST',
          payload: {'studentId': student},
          module: 'attendance',
          dedupeKey: 'attendance:s1:$student',
        );
      }

      expect(await outbox.due(), hasLength(2));
    });

    test('a retryable failure backs off and leaves the entry queued', () async {
      final id = await outbox.enqueue(
        endpoint: '/x',
        method: 'POST',
        payload: const {},
        module: 'attendance',
      );

      await outbox.markRetryable(id, 'No internet connection', 0);

      // Still counted as pending work, but not due yet.
      expect(await outbox.pendingCount(), 1);
      expect(await outbox.due(), isEmpty);
    });

    test('a blocked entry stops being retried but stays visible', () async {
      final id = await outbox.enqueue(
        endpoint: '/x',
        method: 'POST',
        payload: const {},
        module: 'attendance',
      );

      await outbox.markBlocked(id, 'You do not have access to this');

      expect(await outbox.due(), isEmpty);
      expect(await outbox.pendingCount(), 0);

      final all = await outbox.watchAll().first;
      expect(all, hasLength(1));
      expect(all.first.isBlocked, isTrue);
      expect(all.first.lastError, contains('access'));
    });

    test('a blocked entry is not replaced by a later dedupe write', () async {
      // Otherwise a rejected write would silently vanish when the user tried
      // again, and they would never learn it had failed.
      final id = await outbox.enqueue(
        endpoint: '/x',
        method: 'POST',
        payload: const {'v': 1},
        module: 'attendance',
        dedupeKey: 'k',
      );
      await outbox.markBlocked(id, 'rejected');

      await outbox.enqueue(
        endpoint: '/x',
        method: 'POST',
        payload: const {'v': 2},
        module: 'attendance',
        dedupeKey: 'k',
      );

      final all = await outbox.watchAll().first;
      expect(all, hasLength(2));
    });
  });

  group('CacheStore', () {
    test('round-trips a document', () async {
      await cache.write('students', 'st1', {'id': 'st1', 'name': 'Aisha'});

      expect(await cache.read('students', 'st1'), {
        'id': 'st1',
        'name': 'Aisha',
      });
    });

    test('reads a group by its index', () async {
      await cache.writeAll(
        'attendance_marks',
        [
          {'studentId': 'st1', 'sessionId': 's1'},
          {'studentId': 'st2', 'sessionId': 's1'},
          {'studentId': 'st3', 'sessionId': 's2'},
        ],
        keyOf: (json) => '${json['sessionId']}:${json['studentId']}',
        groupKeyOf: (json) => json['sessionId'] as String,
      );

      expect(await cache.readGroup('attendance_marks', 's1'), hasLength(2));
      expect(await cache.readGroup('attendance_marks', 's2'), hasLength(1));
    });

    test('replaceGroup drops rows that are gone from the server', () async {
      await cache.writeAll(
        'attendance_marks',
        [
          {'studentId': 'st1', 'sessionId': 's1'},
          {'studentId': 'st2', 'sessionId': 's1'},
        ],
        keyOf: (json) => '${json['sessionId']}:${json['studentId']}',
        groupKeyOf: (json) => json['sessionId'] as String,
      );

      await cache.replaceGroup(
        'attendance_marks',
        's1',
        [
          {'studentId': 'st1', 'sessionId': 's1'},
        ],
        keyOf: (json) => '${json['sessionId']}:${json['studentId']}',
      );

      final rows = await cache.readGroup('attendance_marks', 's1');
      expect(rows, hasLength(1));
      expect(rows.single['studentId'], 'st1');
    });

    test('clearDataCaches keeps settings and leaves the outbox alone', () async {
      await cache.write('students', 'st1', {'id': 'st1'});
      await cache.write('settings', 'theme', {'mode': 'dark'});
      await outbox.enqueue(
        endpoint: '/x',
        method: 'POST',
        payload: const {},
        module: 'attendance',
      );

      await cache.clearDataCaches();

      expect(await cache.read('students', 'st1'), isNull);
      expect(await cache.read('settings', 'theme'), isNotNull);
      expect(await outbox.pendingCount(), 1);
    });

    test('a corrupt row is skipped, not thrown', () async {
      await cache.write('students', 'ok', {'id': 'ok'});
      await db
          .into(db.cacheEntries)
          .insertOnConflictUpdate(
            CacheEntriesCompanion.insert(
              box: 'students',
              key: 'bad',
              value: 'not json',
            ),
          );

      final rows = await cache.readAll('students');
      expect(rows, hasLength(1));
      expect(rows.single['id'], 'ok');
    });
  });
}
