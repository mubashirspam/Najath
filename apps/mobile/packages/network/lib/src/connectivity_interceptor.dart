import 'package:dio/dio.dart';

/// Normalises transport faults into a single, recognisable shape.
///
/// Without this, a dropped connection surfaces as half a dozen different
/// `DioExceptionType`s with platform-specific messages, and every call site
/// ends up string-matching.
class ConnectivityInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: 'No internet connection',
          type: DioExceptionType.connectionError,
        ),
      );
      return;
    }
    handler.next(err);
  }
}
