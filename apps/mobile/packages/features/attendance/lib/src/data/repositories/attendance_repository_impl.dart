import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_local_db/najath_local_db.dart';
import 'package:najath_network/najath_network.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/attendance.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/attendance_remote_datasource.dart';
import '../dto/attendance_dto.dart';
import '../mappers/attendance_mapper.dart';

const _uuid = Uuid();

/// Offline-first attendance.
///
/// Reads stream from SQLite, always. Writes commit to SQLite first and queue
/// the request — a teacher taking roll in a hall with no signal cannot be asked
/// to wait, and must not lose the mark if the app is killed.
class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl({
    required AttendanceRemoteDataSource remote,
    required AttendanceDao dao,
    required OutboxStore outbox,
    required bool Function() isOnline,
  }) : _remote = remote,
       _dao = dao,
       _outbox = outbox,
       _isOnline = isOnline;

  final AttendanceRemoteDataSource _remote;
  final AttendanceDao _dao;
  final OutboxStore _outbox;
  final bool Function() _isOnline;

  static const _entity = 'attendance';

  @override
  Stream<List<AttendanceEntry>> watchRoster({
    required String batchId,
    required String date,
    required AttendanceSession session,
  }) {
    final roster = _dao.watchBatchRoster(
      batchId: batchId,
      date: date,
      session: session.wire,
    );
    final pending = _outbox.watchPendingIds(_entity);

    // Two streams because they change independently: a mark repaints the
    // roster, and the outbox draining repaints only the "will send" markers.
    return _combine(roster, pending);
  }

  Stream<List<AttendanceEntry>> _combine(
    Stream<List<RosterRow>> roster,
    Stream<Set<String>> pending,
  ) async* {
    var pendingIds = <String>{};
    await for (final rows in _merge(roster, pending, (ids) => pendingIds = ids)) {
      yield rows
          .map(
            (row) => AttendanceMapper.fromRosterRow(
              row,
              isPending: row.record != null && pendingIds.contains(row.record!.id),
            ),
          )
          .toList();
    }
  }

  /// Emits the roster whenever either source changes, keeping the latest of
  /// each. Hand-rolled rather than pulling in rxdart for one combine.
  Stream<List<RosterRow>> _merge(
    Stream<List<RosterRow>> roster,
    Stream<Set<String>> pending,
    void Function(Set<String>) onPending,
  ) {
    final controller = StreamController<List<RosterRow>>();
    List<RosterRow>? latest;

    final rosterSub = roster.listen((rows) {
      latest = rows;
      controller.add(rows);
    }, onError: controller.addError);

    final pendingSub = pending.listen((ids) {
      onPending(ids);
      if (latest != null) controller.add(latest!);
    }, onError: controller.addError);

    controller.onCancel = () async {
      await rosterSub.cancel();
      await pendingSub.cancel();
    };

    return controller.stream;
  }

  @override
  Future<Result<void>> refreshRoster({
    required String batchId,
    required String date,
    required AttendanceSession session,
  }) async {
    if (!_isOnline()) return fail(const Failure.unavailableOffline());

    final result = await _remote.fetchRoster(
      batchId: batchId,
      date: date,
      session: session.wire,
    );

    final failure = result.failureOrNull;
    if (failure != null) return fail(failure);

    await _dao.mergeFromServer(
      result.valueOrNull!.marks
          .map((dto) => AttendanceMapper.toCompanion(dto, isPending: false))
          .toList(),
    );
    return ok(null);
  }

  @override
  Future<Result<void>> mark({
    required String batchId,
    required String enrollmentId,
    required String date,
    required AttendanceSession session,
    required AttendanceStatus status,
    int? minutesLate,
    String? remark,
  }) async {
    // Client-generated UUID v7. The server accepts it, so there is no temp-id
    // remapping — which is where offline sync usually goes wrong.
    final id = _uuid.v7();

    final dto = AttendanceMarkDto(
      id: id,
      enrollmentId: enrollmentId,
      attendanceDate: date,
      session: session.wire,
      status: status.wire,
      markedAt: DateTime.now().toUtc(),
      minutesLate: minutesLate,
      remark: remark,
    );

    // Local first. The roster repaints on the next frame either way.
    await _dao.upsertMark(AttendanceMapper.toCompanion(dto, isPending: true));

    // Keyed on the natural key, not the row id: correcting the same student
    // three times offline replaces the queued entry rather than queueing three
    // requests, and the last answer wins.
    await _outbox.enqueue(
      id: id,
      entity: _entity,
      operation: 'create',
      endpoint: ApiEndpoints.attendanceBatch,
      payload: {
        'marks': [dto.toJson()],
      },
      idempotencyKey: _idempotencyKey(enrollmentId, date, session.wire),
      label: status.name,
    );

    return ok(null);
  }

  /// `sha256(entity + naturalKey)`, per the sync rules.
  ///
  /// The natural key is `(enrollment, date, session)` — the thing that can only
  /// have one current value — so a retry of a *correction* dedupes against the
  /// original rather than creating a second row.
  String _idempotencyKey(String enrollmentId, String date, String session) {
    final input = '$_entity:$enrollmentId:$date:$session';
    return sha256.convert(utf8.encode(input)).toString();
  }

  @override
  Future<Result<List<AttendanceEntry>>> history({
    required String enrollmentId,
    required String date,
  }) async {
    final records = await _dao.historyFor(enrollmentId: enrollmentId, date: date);
    return ok(
      records
          .map(
            (r) => AttendanceMapper.fromRecord(
              r,
              studentId: '',
              studentName: '',
            ),
          )
          .toList(),
    );
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepositoryImpl(
    remote: ref.watch(attendanceRemoteDataSourceProvider),
    dao: ref.watch(attendanceDaoProvider),
    outbox: ref.watch(outboxStoreProvider),
    isOnline: () => ref.read(isOnlineProvider),
  );
});
