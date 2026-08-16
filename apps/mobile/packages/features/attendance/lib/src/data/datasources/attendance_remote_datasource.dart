import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_network/najath_network.dart';

import '../dto/attendance_dto.dart';

/// A roster as the server sees it, plus the time it was generated.
///
/// The server's clock is the cursor for the next delta pull; a device clock
/// minutes fast would silently skip rows.
class RemoteRoster {
  const RemoteRoster({required this.marks, required this.serverTime});

  final List<AttendanceMarkDto> marks;
  final DateTime serverTime;
}

class AttendanceRemoteDataSource {
  AttendanceRemoteDataSource(this._client);

  final DioClient _client;

  Future<Result<RemoteRoster>> fetchRoster({
    required String batchId,
    required String date,
    required String session,
    CancelToken? cancelToken,
  }) {
    return _client.get<RemoteRoster>(
      endpoint: ApiEndpoints.attendanceRoster,
      queryParameters: {'batchId': batchId, 'date': date, 'session': session},
      cancelToken: cancelToken,
      decode: (body) {
        final list = body is List ? body : (body as Map)['marks'] as List? ?? const [];
        return RemoteRoster(
          marks: list.whereType<Map<String, dynamic>>().map(AttendanceMarkDto.fromJson).toList(),
          serverTime: DateTime.now().toUtc(),
        );
      },
    );
  }

  /// Up to 100 marks in one request, with a per-item result so one bad row does
  /// not fail the other ninety-nine.
  Future<Result<void>> submitBatch({
    required List<AttendanceMarkDto> marks,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) {
    return _client.post<void>(
      endpoint: ApiEndpoints.attendanceBatch,
      idempotencyKey: idempotencyKey,
      cancelToken: cancelToken,
      data: {'marks': marks.map((m) => m.toJson()).toList()},
      decode: (_) {},
    );
  }
}

final attendanceRemoteDataSourceProvider = Provider<AttendanceRemoteDataSource>((
  ref,
) {
  return AttendanceRemoteDataSource(ref.watch(dioClientProvider));
});
