import 'package:najath_core/najath_core.dart';

enum Status { initial, loading, completed, error }

/// The uniform envelope every remote call returns.
///
/// A value rather than an exception: transport faults and non-2xx responses are
/// both classified into an [ApiError] and carried here, so repositories branch
/// instead of catching, and an offline read path can fall through to the cache
/// without a try block.
class ApiResponse<T> {
  const ApiResponse._(this.status, this.data, this.error);

  const ApiResponse.initial() : this._(Status.initial, null, null);

  const ApiResponse.loading() : this._(Status.loading, null, null);

  const ApiResponse.completed(T value) : this._(Status.completed, value, null);

  const ApiResponse.error(ApiError failure) : this._(Status.error, null, failure);

  final Status status;
  final T? data;
  final ApiError? error;

  bool get isInitial => status == Status.initial;
  bool get isLoading => status == Status.loading;
  bool get isCompleted => status == Status.completed;
  bool get isError => status == Status.error;

  /// True only when the call succeeded *and* produced a value — the check
  /// repositories actually want before touching [data].
  bool get hasData => isCompleted && data != null;

  /// The value, or [fallback] for anything else.
  T orElse(T fallback) => hasData ? data as T : fallback;

  /// Re-types a failed response so an error can be propagated across a call
  /// that returns a different payload type.
  ApiResponse<R> castError<R>() => ApiResponse<R>.error(
    error ?? const ApiError(message: 'Unknown error', code: ApiErrorCode.unknown),
  );

  /// Maps a successful payload, preserving the failure channel.
  ApiResponse<R> map<R>(R Function(T value) transform) {
    if (hasData) {
      return ApiResponse<R>.completed(transform(data as T));
    }
    return castError<R>();
  }

  R when<R>({
    required R Function() onInitial,
    required R Function() onLoading,
    required R Function(T data) onCompleted,
    required R Function(ApiError error) onError,
  }) {
    switch (status) {
      case Status.initial:
        return onInitial();
      case Status.loading:
        return onLoading();
      case Status.completed:
        return onCompleted(data as T);
      case Status.error:
        return onError(error!);
    }
  }

  @override
  String toString() =>
      isError ? 'ApiResponse.error(${error!.message})' : 'ApiResponse($status, $data)';
}
