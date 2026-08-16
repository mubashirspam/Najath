import 'package:dio/dio.dart';
import 'package:najath_core/najath_core.dart';

/// Turns transport faults and error envelopes into a [Failure].
///
/// This is the **only** place in the app where a `DioException` or an HTTP
/// status is interpreted. Nothing above the data layer catches a raw exception,
/// which is what makes the repository signatures honest.
class FailureMapper {
  FailureMapper._();

  /// A thrown transport fault. Status-code failures never reach here —
  /// `DioClient` sets `validateStatus: (_) => true` — so this only sees
  /// timeouts, DNS, cancellation and TLS.
  static Failure fromException(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const Failure.timeout(),
    DioExceptionType.connectionError => const Failure.network(),
    DioExceptionType.badCertificate => const Failure.server('BAD_CERTIFICATE'),
    DioExceptionType.cancel => const Failure.server('CANCELLED'),
    _ => _classifyUnknown(e),
  };

  static Failure _classifyUnknown(DioException e) {
    final text = (e.error ?? e).toString();
    if (text.contains('SocketException') || text.contains('Connection')) {
      return const Failure.network();
    }
    return Failure.unknown(e.error ?? e, e.stackTrace);
  }

  /// A non-2xx response body, in the envelope from `@najath/contracts`:
  ///
  /// ```jsonc
  /// { "error": { "code": "HIFZ_RANGE_OVERLAP", "field": "fromAyah", "details": {} } }
  /// ```
  static Failure fromResponse(int statusCode, Object? body) {
    final error = _errorObject(body);
    final code = error?['code']?.toString();

    return switch (statusCode) {
      401 => const Failure.unauthorized(),
      403 => Failure.forbidden(code ?? 'FORBIDDEN'),
      404 => const Failure.notFound(),
      409 => _conflict(error) ?? Failure.server(code ?? 'CONFLICT'),
      400 || 422 => Failure.validation(_fieldErrors(error)),
      _ => Failure.server(code ?? 'HTTP_$statusCode'),
    };
  }

  static Map<String, dynamic>? _errorObject(Object? body) {
    if (body is! Map) return null;
    final error = body['error'];
    return error is Map<String, dynamic> ? error : null;
  }

  /// Field name → message, so a form can highlight the offending input rather
  /// than dropping the whole thing into a toast.
  static Map<String, String> _fieldErrors(Map<String, dynamic>? error) {
    if (error == null) return const {};

    final details = error['details'];
    final issues = details is Map ? details['issues'] : null;
    if (issues is List) {
      return {
        for (final issue in issues)
          if (issue is Map && issue['path'] != null)
            issue['path'].toString(): issue['message']?.toString() ?? 'Invalid',
      };
    }

    final field = error['field']?.toString();
    if (field != null) {
      return {field: error['code']?.toString() ?? 'INVALID'};
    }
    return {'_': error['code']?.toString() ?? 'VALIDATION'};
  }

  /// A 409 on a teacher-authored record carries both versions so the teacher
  /// can choose. Anything else that 409s is an ordinary server error.
  static Failure? _conflict(Map<String, dynamic>? error) {
    final details = error?['details'];
    if (details is! Map) return null;

    final mine = details['mine'];
    final theirs = details['theirs'];
    if (mine is! Map || theirs is! Map) return null;

    return Failure.conflict(
      ConflictPayload(
        entity: details['entity']?.toString() ?? 'unknown',
        entityId: details['entityId']?.toString() ?? '',
        mine: Map<String, dynamic>.from(mine),
        theirs: Map<String, dynamic>.from(theirs),
      ),
    );
  }
}
