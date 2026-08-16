/// A structured, already-classified failure.
///
/// Non-2xx responses are turned into one of these rather than thrown, so call
/// sites branch on a value instead of catching.
class ApiError {
  const ApiError({required this.message, this.statusCode, this.code, this.data});

  factory ApiError.fromException(Object exception) {
    final text = exception.toString();
    if (text.contains('SocketException') || text.contains('Connection')) {
      return const ApiError(
        message: 'No internet connection',
        code: ApiErrorCode.network,
      );
    }
    return ApiError(message: text, code: ApiErrorCode.unknown);
  }

  factory ApiError.network([String message = 'No internet connection']) =>
      ApiError(message: message, code: ApiErrorCode.network);

  factory ApiError.server(String message, {int? statusCode}) =>
      ApiError(message: message, statusCode: statusCode, code: ApiErrorCode.server);

  factory ApiError.unauthorized([String message = 'Session expired']) =>
      ApiError(message: message, statusCode: 401, code: ApiErrorCode.unauthorized);

  /// The server accepted the identity but refused the action. Distinct from
  /// [unauthorized]: re-authenticating will not help, the role lacks the
  /// permission.
  factory ApiError.forbidden([String message = 'You do not have access to this']) =>
      ApiError(message: message, statusCode: 403, code: ApiErrorCode.forbidden);

  factory ApiError.validation(String message, {Object? data}) => ApiError(
    message: message,
    statusCode: 422,
    code: ApiErrorCode.validation,
    data: data,
  );

  /// Nothing cached and no network — the offline-first read path's miss case.
  factory ApiError.unavailableOffline() => const ApiError(
    message: 'Not available offline yet',
    code: ApiErrorCode.offline,
  );

  final String message;
  final int? statusCode;
  final String? code;
  final Object? data;

  bool get isNetworkError => code == ApiErrorCode.network;
  bool get isServerError => code == ApiErrorCode.server;
  bool get isUnauthorized => code == ApiErrorCode.unauthorized;
  bool get isForbidden => code == ApiErrorCode.forbidden;
  bool get isValidationError => code == ApiErrorCode.validation;
  bool get isOffline => code == ApiErrorCode.offline;

  /// Whether retrying the same request later could plausibly succeed. Drives
  /// whether a write is parked in the outbox or reported as a hard failure.
  bool get isRetryable => isNetworkError || isOffline || (statusCode ?? 0) >= 500;

  @override
  String toString() => 'ApiError(message: $message, code: $code, statusCode: $statusCode)';
}

class ApiErrorCode {
  ApiErrorCode._();

  static const String network = 'NETWORK_ERROR';
  static const String server = 'SERVER_ERROR';
  static const String unauthorized = 'UNAUTHORIZED';
  static const String forbidden = 'FORBIDDEN';
  static const String validation = 'VALIDATION_ERROR';
  static const String offline = 'OFFLINE';
  static const String unknown = 'UNKNOWN_ERROR';
}
