import 'api_error.dart';

/// Thrown only where a `Future` contract cannot carry an [ApiError] value —
/// notably inside `AsyncNotifier.build`, whose failure channel is an exception.
class AppException implements Exception {
  const AppException(this.error);

  final ApiError error;

  String get message => error.message;

  @override
  String toString() => 'AppException(${error.message})';
}

/// The signed-in principal's role does not carry the permission the caller
/// asked for. Raised client-side by the permission guards before a request is
/// ever made, so the UI can explain rather than surface a 403.
class NotPermittedException implements Exception {
  const NotPermittedException(this.resource, this.action);

  final String resource;
  final String action;

  @override
  String toString() => 'NotPermittedException($resource:$action)';
}
