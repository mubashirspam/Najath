import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';

import 'connectivity_interceptor.dart';
import 'failure_mapper.dart';

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
      // Non-2xx is a value, not a throw — `FailureMapper` classifies it.
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
/// matrix since the last fetch — so the auth layer registers a handler that
/// refetches it. A callback because `najath_network` cannot import
/// `najath_auth`; the dependency runs the other way.
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
/// Every remote source goes through here, so bearer injection, failure
/// classification and the 401/403 reactions live in exactly one place. Returns
/// [Result] rather than throwing: a caller that forgets the failure branch is a
/// compile error, not a crash in a halaqa.
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

  Future<Result<T>> request<T>({
    required String endpoint,
    required HttpMethod method,
    required T Function(dynamic body) decode,
    bool isAuth = false,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? contentType,
    String? idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    try {
      final requestHeaders = await _buildHeaders(
        custom: headers,
        contentType: contentType ?? Headers.jsonContentType,
        idempotencyKey: idempotencyKey,
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

      return _toResult<T>(response, decode);
    } on DioException catch (e) {
      return fail(FailureMapper.fromException(e));
    } on Object catch (e, stack) {
      return fail(Failure.unknown(e, stack));
    }
  }

  Future<Result<T>> get<T>({
    required String endpoint,
    required T Function(dynamic body) decode,
    bool isAuth = false,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) => request<T>(
    endpoint: endpoint,
    method: HttpMethod.get,
    decode: decode,
    isAuth: isAuth,
    queryParameters: queryParameters,
    cancelToken: cancelToken,
  );

  Future<Result<T>> post<T>({
    required String endpoint,
    required T Function(dynamic body) decode,
    Object? data,
    bool isAuth = false,
    Map<String, dynamic>? queryParameters,
    String? idempotencyKey,
    CancelToken? cancelToken,
  }) => request<T>(
    endpoint: endpoint,
    method: HttpMethod.post,
    decode: decode,
    data: data,
    isAuth: isAuth,
    queryParameters: queryParameters,
    idempotencyKey: idempotencyKey,
    cancelToken: cancelToken,
  );

  Future<Result<T>> patch<T>({
    required String endpoint,
    required T Function(dynamic body) decode,
    Object? data,
    String? idempotencyKey,
    CancelToken? cancelToken,
  }) => request<T>(
    endpoint: endpoint,
    method: HttpMethod.patch,
    decode: decode,
    data: data,
    idempotencyKey: idempotencyKey,
    cancelToken: cancelToken,
  );

  Future<Result<T>> delete<T>({
    required String endpoint,
    required T Function(dynamic body) decode,
    Object? data,
    CancelToken? cancelToken,
  }) => request<T>(
    endpoint: endpoint,
    method: HttpMethod.delete,
    decode: decode,
    data: data,
    cancelToken: cancelToken,
  );

  /// Multipart upload — student photos, exam attachments, hifz audio.
  Future<Result<T>> uploadFile<T>({
    required String endpoint,
    required FormData formData,
    required T Function(dynamic body) decode,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final headers = await _buildHeaders(contentType: 'multipart/form-data');

      final response = await _dio.post<dynamic>(
        _resolveUrl(endpoint, isAuth: false),
        data: formData,
        options: Options(headers: headers),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );

      return _toResult<T>(response, decode);
    } on DioException catch (e) {
      return fail(FailureMapper.fromException(e));
    } on Object catch (e, stack) {
      return fail(Failure.unknown(e, stack));
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
    String? idempotencyKey,
  }) async {
    final headers = <String, String>{
      'Content-Type': contentType,
      'Accept': 'application/json',
      // Required on anything the outbox can replay. The server dedupes for
      // seven days, which is what makes "the phone retried mid-commit" safe.
      'Idempotency-Key': ?idempotencyKey,
      ...?custom,
    };
    final token = await _tokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Result<T> _toResult<T>(
    Response<dynamic> response,
    T Function(dynamic body) decode,
  ) {
    final statusCode = response.statusCode ?? 0;

    if (statusCode >= 200 && statusCode < 300) {
      try {
        // The success envelope is `{ data, meta }`; decoders see `data`.
        final body = response.data;
        final payload = body is Map && body.containsKey('data') ? body['data'] : body;
        return ok(decode(payload));
      } on Object catch (e, stack) {
        // A shape the client did not expect is a contract break, not a
        // transport problem — surfacing it as `unknown` keeps them separable in
        // Crashlytics.
        return fail(Failure.unknown(e, stack));
      }
    }

    final failure = FailureMapper.fromResponse(statusCode, response.data);

    // Better Auth returns 401 once the session record is gone; there is no
    // refresh grant to try, so the only correct move is to end the session.
    if (failure is UnauthorizedFailure) _hooks.onUnauthorized?.call();

    // A 403 on a request the UI thought was allowed means the role matrix moved
    // under us. Refetch rather than leaving a dead screen.
    if (failure is ForbiddenFailure) _hooks.onForbidden?.call();

    return fail(failure);
  }
}
