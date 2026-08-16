import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';

import 'api_response.dart';
import 'connectivity_interceptor.dart';

enum HttpMethod { get, post, put, patch, delete }

extension on HttpMethod {
  String get value => name.toUpperCase();
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: AppDurations.connectTimeout,
      receiveTimeout: AppDurations.receiveTimeout,
      sendTimeout: AppDurations.connectTimeout,
      headers: const {'Accept': 'application/json'},
      // Non-2xx is a value, not a throw — `_toApiResponse` classifies it.
      validateStatus: (_) => true,
    ),
  )..interceptors.add(ConnectivityInterceptor());

  if (Env.enableLogging) {
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  }

  ref.onDispose(dio.close);
  return dio;
});

/// Called when the server rejects a request the client believed was permitted.
///
/// A 403 means the cached access policy is stale — an admin changed the role
/// matrix since the last fetch — so the auth layer registers a handler here
/// that refetches it. Kept as a callback so `najath_network` does not have to
/// depend on `najath_auth`.
typedef ForbiddenHandler = void Function();

/// Called when the session is gone and the user must sign in again.
typedef UnauthorizedHandler = void Function();

class DioClientHooks {
  DioClientHooks({this.onForbidden, this.onUnauthorized});

  ForbiddenHandler? onForbidden;
  UnauthorizedHandler? onUnauthorized;
}

final dioClientHooksProvider = Provider<DioClientHooks>((ref) => DioClientHooks());

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(
    dio: ref.watch(dioProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
    hooks: ref.watch(dioClientHooksProvider),
  );
});

/// The single HTTP entry point.
///
/// Every remote source goes through here so bearer injection, error
/// classification and the 401/403 reactions live in exactly one place.
class DioClient {
  DioClient({
    required Dio dio,
    required TokenStorage tokenStorage,
    required DioClientHooks hooks,
  }) : _dio = dio,
       _tokenStorage = tokenStorage,
       _hooks = hooks;

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final DioClientHooks _hooks;

  Future<ApiResponse<T>> request<T>({
    required String endpoint,
    required HttpMethod method,
    bool isAuth = false,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? contentType,
    CancelToken? cancelToken,
    T Function(dynamic body)? mapper,
  }) async {
    try {
      final requestHeaders = await _buildHeaders(
        custom: headers,
        contentType: contentType ?? Headers.jsonContentType,
      );

      final response = await _dio.request<dynamic>(
        _resolveUrl(endpoint, isAuth: isAuth),
        data: data,
        queryParameters: queryParameters,
        options: Options(
          method: method.value,
          headers: requestHeaders,
          contentType: contentType,
        ),
        cancelToken: cancelToken,
      );

      return _toApiResponse<T>(response, mapper);
    } on DioException catch (e) {
      return ApiResponse<T>.error(ApiErrorHandler.toApiError(e));
    } on Object catch (e) {
      return ApiResponse<T>.error(ApiError.fromException(e));
    }
  }

  Future<ApiResponse<T>> get<T>({
    required String endpoint,
    bool isAuth = false,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    T Function(dynamic body)? mapper,
  }) => request<T>(
    endpoint: endpoint,
    method: HttpMethod.get,
    isAuth: isAuth,
    queryParameters: queryParameters,
    headers: headers,
    cancelToken: cancelToken,
    mapper: mapper,
  );

  Future<ApiResponse<T>> post<T>({
    required String endpoint,
    Object? data,
    bool isAuth = false,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? contentType,
    CancelToken? cancelToken,
    T Function(dynamic body)? mapper,
  }) => request<T>(
    endpoint: endpoint,
    method: HttpMethod.post,
    isAuth: isAuth,
    data: data,
    queryParameters: queryParameters,
    headers: headers,
    contentType: contentType,
    cancelToken: cancelToken,
    mapper: mapper,
  );

  Future<ApiResponse<T>> put<T>({
    required String endpoint,
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    T Function(dynamic body)? mapper,
  }) => request<T>(
    endpoint: endpoint,
    method: HttpMethod.put,
    data: data,
    queryParameters: queryParameters,
    cancelToken: cancelToken,
    mapper: mapper,
  );

  Future<ApiResponse<T>> patch<T>({
    required String endpoint,
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    T Function(dynamic body)? mapper,
  }) => request<T>(
    endpoint: endpoint,
    method: HttpMethod.patch,
    data: data,
    queryParameters: queryParameters,
    cancelToken: cancelToken,
    mapper: mapper,
  );

  Future<ApiResponse<T>> delete<T>({
    required String endpoint,
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    T Function(dynamic body)? mapper,
  }) => request<T>(
    endpoint: endpoint,
    method: HttpMethod.delete,
    data: data,
    queryParameters: queryParameters,
    cancelToken: cancelToken,
    mapper: mapper,
  );

  /// Multipart upload — student photos, exam attachments, hifz audio.
  Future<ApiResponse<T>> uploadFile<T>({
    required String endpoint,
    required FormData formData,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    T Function(dynamic body)? mapper,
  }) async {
    try {
      final headers = await _buildHeaders(
        contentType: 'multipart/form-data',
      );

      final response = await _dio.post<dynamic>(
        _resolveUrl(endpoint, isAuth: false),
        data: formData,
        queryParameters: queryParameters,
        options: Options(headers: headers),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );

      return _toApiResponse<T>(response, mapper);
    } on DioException catch (e) {
      return ApiResponse<T>.error(ApiErrorHandler.toApiError(e));
    } on Object catch (e) {
      return ApiResponse<T>.error(ApiError.fromException(e));
    }
  }

  String _resolveUrl(String endpoint, {required bool isAuth}) {
    if (endpoint.startsWith('http')) return endpoint;
    final base = isAuth ? Env.current.authBaseUrl : Env.apiBaseUrl;
    return '$base$endpoint';
  }

  /// Bearer token on every request, including the auth ones — Better Auth's
  /// bearer plugin ignores it on sign-in and needs it on sign-out.
  Future<Map<String, String>> _buildHeaders({
    Map<String, String>? custom,
    String contentType = Headers.jsonContentType,
  }) async {
    final headers = <String, String>{
      'Content-Type': contentType,
      'Accept': 'application/json',
      ...?custom,
    };
    final token = await _tokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  ApiResponse<T> _toApiResponse<T>(
    Response<dynamic> response,
    T Function(dynamic body)? mapper,
  ) {
    final statusCode = response.statusCode ?? 0;
    final body = response.data;

    if (statusCode >= 200 && statusCode < 300) {
      try {
        return ApiResponse<T>.completed(
          mapper != null ? mapper(body) : body as T,
        );
      } on Object catch (e) {
        return ApiResponse<T>.error(
          ApiError(message: 'Could not read the response: $e'),
        );
      }
    }

    final error = _classify(statusCode, body);

    // Better Auth returns 401 once the session record is gone; there is no
    // refresh grant to try, so the only correct move is to end the session.
    if (error.isUnauthorized) {
      _hooks.onUnauthorized?.call();
    }
    // A 403 on a request the UI thought was allowed means the role matrix moved
    // under us. Ask the auth layer to refetch rather than leaving a dead screen.
    if (error.isForbidden) {
      _hooks.onForbidden?.call();
    }

    return ApiResponse<T>.error(error);
  }

  ApiError _classify(int statusCode, dynamic body) {
    final message = ApiErrorHandler.messageFromBody(body) ?? _defaultMessage(statusCode);

    switch (statusCode) {
      case 401:
        return ApiError.unauthorized(message);
      case 403:
        return ApiError.forbidden(message);
      case 400:
      case 422:
        return ApiError.validation(
          message,
          data: body is Map ? body['issues'] : null,
        );
      default:
        return ApiError.server(message, statusCode: statusCode);
    }
  }

  String _defaultMessage(int statusCode) => switch (statusCode) {
    400 => 'Bad request',
    401 => 'Your session has expired',
    403 => 'You do not have access to this',
    404 => 'Not found',
    409 => 'That conflicts with something already saved',
    429 => 'Too many attempts — try again shortly',
    500 => 'Server error',
    502 => 'Bad gateway',
    503 => 'Service unavailable',
    _ => 'Request failed (status $statusCode)',
  };
}
