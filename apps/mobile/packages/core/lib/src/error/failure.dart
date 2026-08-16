import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'failure.freezed.dart';

/// A conflict the server could not resolve on its own.
///
/// Master data is server-wins and never reaches here. This is for
/// teacher-authored records — a hifz log edited on two devices — where the
/// teacher has to choose, so both versions travel to the conflict card.
@freezed
abstract class ConflictPayload with _$ConflictPayload {
  const factory ConflictPayload({
    required String entity,
    required String entityId,
    required Map<String, dynamic> mine,
    required Map<String, dynamic> theirs,
  }) = _ConflictPayload;
}

/// Everything that can go wrong, as a closed set.
///
/// Sealed so a `switch` over it is exhaustive: adding a variant breaks every
/// call site that has to care, at compile time, rather than falling through a
/// `default` in production.
///
/// **Carries codes, never sentences.** The domain layer has no English strings
/// in it — the presentation layer maps these to localized copy, so the same
/// failure reads correctly in English and Malayalam.
@freezed
sealed class Failure with _$Failure {
  /// No transport at all. Distinct from a timeout: retrying now is pointless,
  /// retrying when connectivity returns is not.
  const factory Failure.network() = NetworkFailure;

  /// A transport existed but the server did not answer in time.
  const factory Failure.timeout() = TimeoutFailure;

  /// The session is gone. Re-authenticating is the only fix.
  const factory Failure.unauthorized() = UnauthorizedFailure;

  /// Authenticated, but the role or scope does not permit this. Re-authenticating
  /// will not help. [reason] is the server's `error.code`, not prose.
  const factory Failure.forbidden(String reason) = ForbiddenFailure;

  /// Field-level rejection. Keys are field names so a form can highlight them.
  const factory Failure.validation(Map<String, String> fieldErrors) = ValidationFailure;

  /// Two versions of a teacher-authored record. The teacher resolves it.
  const factory Failure.conflict(ConflictPayload payload) = ConflictFailure;

  const factory Failure.notFound() = NotFoundFailure;

  /// A server-side error, carrying the closed-enum code from `@najath/contracts`.
  const factory Failure.server(String code) = ServerFailure;

  /// Nothing is cached and there is no network — the offline-first read path's
  /// miss case. Not an error the user did anything to cause.
  const factory Failure.unavailableOffline() = UnavailableOfflineFailure;

  const factory Failure.unknown(Object error, StackTrace stackTrace) = UnknownFailure;
}

extension FailureX on Failure {
  /// Whether retrying the same request later could plausibly succeed.
  ///
  /// Drives whether a queued write stays in the outbox or is parked as blocked:
  /// a validation error will fail identically forever, a timeout will not.
  bool get isRetryable => switch (this) {
    NetworkFailure() || TimeoutFailure() || UnavailableOfflineFailure() => true,
    ServerFailure() => true,
    UnauthorizedFailure() => true, // the outbox pauses for refresh, never drops
    ForbiddenFailure() ||
    ValidationFailure() ||
    ConflictFailure() ||
    NotFoundFailure() ||
    UnknownFailure() => false,
  };

  /// True when the app is simply not connected, as opposed to something being
  /// wrong. The UI phrases these differently — offline is a normal state in a
  /// boarding academy.
  bool get isOffline => switch (this) {
    NetworkFailure() || UnavailableOfflineFailure() => true,
    _ => false,
  };

  /// A stable identifier for logs and analytics. Never shown to a user.
  String get code => switch (this) {
    NetworkFailure() => 'NETWORK',
    TimeoutFailure() => 'TIMEOUT',
    UnauthorizedFailure() => 'UNAUTHORIZED',
    ForbiddenFailure(:final reason) => reason,
    ValidationFailure() => 'VALIDATION',
    ConflictFailure() => 'CONFLICT',
    NotFoundFailure() => 'NOT_FOUND',
    ServerFailure(:final code) => code,
    UnavailableOfflineFailure() => 'UNAVAILABLE_OFFLINE',
    UnknownFailure() => 'UNKNOWN',
  };
}

/// The result of anything that can fail.
///
/// `Left` is the failure, `Right` is the value — the convention `fpdart` and
/// every other Either follow. Call sites `fold` rather than branching on a
/// status field, so forgetting the failure path is a compile error.
typedef Result<T> = Either<Failure, T>;

/// Wraps a value as a success.
Result<T> ok<T>(T value) => Right(value);

/// Wraps a failure.
Result<T> fail<T>(Failure failure) => Left(failure);

extension ResultX<T> on Result<T> {
  bool get isOk => isRight();
  bool get isFailure => isLeft();

  /// The value, or null. Use sparingly — `fold` is almost always clearer.
  T? get valueOrNull => fold((_) => null, (value) => value);

  Failure? get failureOrNull => fold((failure) => failure, (_) => null);
}
