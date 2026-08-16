import 'package:dio/dio.dart';

import 'api_error.dart';

/// Turns a thrown [DioException] into a classified [ApiError].
///
/// `DioClient` sets `validateStatus: (_) => true`, so status-code failures never
/// reach here — this only handles transport-level faults: timeouts, DNS,
/// cancellation, TLS.
class ApiErrorHandler {
  ApiErrorHandler._();

  static ApiError toApiError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiError.network('The server took too long to respond');

      case DioExceptionType.connectionError:
        return ApiError.network();

      case DioExceptionType.cancel:
        return const ApiError(
          message: 'Request cancelled',
          code: ApiErrorCode.unknown,
        );

      case DioExceptionType.badCertificate:
        return ApiError.server('Could not verify the server certificate');

      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 401) return ApiError.unauthorized();
        if (status == 403) return ApiError.forbidden();
        return ApiError.server(
          _messageFromBody(e.response?.data) ?? 'Request failed',
          statusCode: status,
        );

      // A default is deliberate here: Dio adds enum members in minor releases,
      // and a new transport fault should degrade to "network problem" rather
      // than fail the build.
      // ignore: no_default_cases
      default:
        // `unknown`, and whatever Dio adds next — treat as a transport fault
        // and let `fromException` classify it from the message.
        return ApiError.fromException(e.error ?? e);
    }
  }

  /// Best effort at the human-readable message the API returned.
  ///
  /// Handles the shapes the Next.js API actually emits: `{ error }` from route
  /// handlers, `{ message }` from Better Auth, and `{ issues: [...] }` from a
  /// Zod parse failure.
  static String? _messageFromBody(Object? body) {
    if (body is String && body.isNotEmpty) return body;
    if (body is! Map) return null;

    final issues = body['issues'];
    if (issues is List && issues.isNotEmpty) {
      final first = issues.first;
      if (first is Map && first['message'] != null) {
        return first['message'].toString();
      }
    }
    return body['message']?.toString() ??
        body['error']?.toString() ??
        body['error_description']?.toString();
  }

  /// Public form of [_messageFromBody], used by `DioClient` for non-2xx bodies
  /// that never became an exception.
  static String? messageFromBody(Object? body) => _messageFromBody(body);
}
