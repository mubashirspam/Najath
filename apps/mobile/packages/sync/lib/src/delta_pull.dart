import 'package:dio/dio.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_network/najath_network.dart';

/// One entity's changes from a delta pull.
class EntityDelta {
  const EntityDelta({
    required this.entity,
    required this.changed,
    required this.tombstones,
  });

  factory EntityDelta.fromJson(Map<String, dynamic> json) {
    return EntityDelta(
      entity: json['entity']?.toString() ?? '',
      changed: (json['changed'] as List? ?? const []).whereType<Map<String, dynamic>>().toList(),
      tombstones: (json['tombstones'] as List? ?? const []).map((e) => e.toString()).toList(),
    );
  }

  final String entity;
  final List<Map<String, dynamic>> changed;

  /// Ids that no longer exist for this user. Applying these is not optional:
  /// without them a transferred-out student stays on the roster forever and is
  /// marked absent every day.
  final List<String> tombstones;
}

class DeltaPullResult {
  const DeltaPullResult({required this.entities, required this.cursor});

  factory DeltaPullResult.fromJson(Map<String, dynamic> json) {
    return DeltaPullResult(
      entities: (json['entities'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(EntityDelta.fromJson)
          .toList(),
      cursor: DateTime.tryParse(json['cursor']?.toString() ?? '')?.toUtc(),
    );
  }

  final List<EntityDelta> entities;

  /// The **server's** clock. Stored verbatim and echoed on the next pull — a
  /// device clock minutes fast would ask for a window that skips rows, and the
  /// loss would be silent.
  final DateTime? cursor;

  EntityDelta? forEntity(String entity) {
    for (final delta in entities) {
      if (delta.entity == entity) return delta;
    }
    return null;
  }
}

/// Fetches everything changed since each entity's cursor, in one request.
///
/// One request rather than one per entity: on a halaqa's connection the round
/// trips cost more than the payload does.
class DeltaPullClient {
  DeltaPullClient(this._client);

  final DioClient _client;

  Future<Result<DeltaPullResult>> pull({
    required List<String> entities,
    DateTime? since,
    CancelToken? cancelToken,
  }) {
    return _client.get<DeltaPullResult>(
      endpoint: ApiEndpoints.syncPull,
      cancelToken: cancelToken,
      queryParameters: {
        'entities': entities.join(','),
        'since': ?since?.toUtc().toIso8601String(),
      },
      decode: (body) => DeltaPullResult.fromJson(body as Map<String, dynamic>),
    );
  }
}
