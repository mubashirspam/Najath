import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_network/najath_network.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/use_cases/sign_in_use_cases.dart';
import 'access_notifier.dart';

/// Which sign-in surface the login screen is showing.
enum SignInMethod { staffPassword, guardianOtp }

@immutable
class AuthState {
  const AuthState._({
    required this.isAuthenticated,
    required this.user,
    required this.isBusy,
    required this.failure,
    required this.initialized,
    required this.method,
    required this.otpRequested,
    required this.rememberMe,
    required this.savedIdentifier,
  });

  const AuthState.initial()
    : isAuthenticated = false,
      user = null,
      isBusy = false,
      failure = null,
      initialized = false,
      method = SignInMethod.staffPassword,
      otpRequested = false,
      rememberMe = false,
      savedIdentifier = null;

  final bool isAuthenticated;
  final AppUser? user;

  /// A sign-in attempt is in flight. Drives the button spinner.
  final bool isBusy;

  /// The last attempt's failure, or null. The login screen maps it to localized
  /// copy — the notifier never carries a sentence.
  final Failure? failure;

  /// False while the stored session is being read back. The router holds every
  /// route on splash until this flips, otherwise a cold start on a deep link
  /// bounces to login before the token has been read.
  final bool initialized;

  final SignInMethod method;

  /// A code has been sent; the guardian should now see the code field.
  final bool otpRequested;

  final bool rememberMe;
  final String? savedIdentifier;

  AuthState copyWith({
    bool? isAuthenticated,
    AppUser? user,
    bool? isBusy,
    Failure? failure,
    bool? initialized,
    SignInMethod? method,
    bool? otpRequested,
    bool? rememberMe,
    String? savedIdentifier,
    bool clearUser = false,
    bool clearFailure = false,
  }) {
    return AuthState._(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: clearUser ? null : (user ?? this.user),
      isBusy: isBusy ?? this.isBusy,
      failure: clearFailure ? null : (failure ?? this.failure),
      initialized: initialized ?? this.initialized,
      method: method ?? this.method,
      otpRequested: otpRequested ?? this.otpRequested,
      rememberMe: rememberMe ?? this.rememberMe,
      savedIdentifier: savedIdentifier ?? this.savedIdentifier,
    );
  }
}

/// Session state machine.
///
/// A `Notifier`, not an `AsyncNotifier`: the redirect guard reads it
/// synchronously and needs [AuthState.initialized], which an `AsyncValue`
/// cannot express — "loading" and "not started" are different answers to the
/// router's question.
class AuthNotifier extends Notifier<AuthState> {
  final Completer<void> _initCompleter = Completer<void>();

  /// Resolves once the stored session has been read. The splash screen awaits
  /// this instead of polling.
  Future<void> get whenInitialized => _initCompleter.future;

  @override
  AuthState build() {
    unawaited(_bootstrap());
    return const AuthState.initial();
  }

  /// Restores the session from storage, then reconciles with the server.
  ///
  /// Offline, the stored session is trusted: the app opens with cached data and
  /// the cached policy. **Only an explicit 401 signs the user out** — a failed
  /// request must never do it, or the app would log people out on the bus.
  Future<void> _bootstrap() async {
    final repository = ref.read(authRepositoryProvider);

    final rememberMe = await repository.getRememberMe();
    final savedIdentifier = await repository.savedIdentifier();

    if (!await repository.hasStoredSession()) {
      _finishBootstrap(
        state.copyWith(
          initialized: true,
          rememberMe: rememberMe,
          savedIdentifier: savedIdentifier,
        ),
      );
      return;
    }

    final cached = await repository.cachedUser();
    if (cached != null) {
      state = state.copyWith(isAuthenticated: true, user: cached);
      await ref.read(accessNotifierProvider.notifier).load(cached.role);
    }

    if (ref.read(isOnlineProvider)) {
      final live = await repository.currentSession();
      final user = live.valueOrNull;

      if (user != null) {
        state = state.copyWith(isAuthenticated: true, user: user);
        await ref.read(accessNotifierProvider.notifier).refresh();
      } else if (live.failureOrNull is UnauthorizedFailure) {
        await _clearLocalSession();
        _finishBootstrap(
          state.copyWith(
            initialized: true,
            rememberMe: rememberMe,
            savedIdentifier: savedIdentifier,
          ),
        );
        return;
      }
    }

    _finishBootstrap(
      state.copyWith(
        initialized: true,
        isAuthenticated: state.user != null,
        rememberMe: rememberMe,
        savedIdentifier: savedIdentifier,
      ),
    );
  }

  void _finishBootstrap(AuthState next) {
    state = next;
    if (!_initCompleter.isCompleted) _initCompleter.complete();
  }

  // ── sign in ────────────────────────────────────────────────────────────────

  void setMethod(SignInMethod method) {
    state = state.copyWith(
      method: method,
      otpRequested: false,
      clearFailure: true,
    );
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    state = state.copyWith(isBusy: true, clearFailure: true);

    final result = await ref
        .read(signInWithEmailUseCaseProvider)
        .call(email: email, password: password, rememberMe: rememberMe);

    return _applySignIn(result, rememberMe: rememberMe, identifier: email);
  }

  Future<bool> requestOtp(String phoneNumber) async {
    state = state.copyWith(isBusy: true, clearFailure: true);

    final result = await ref.read(requestPhoneOtpUseCaseProvider).call(phoneNumber);
    final failure = result.failureOrNull;

    if (failure != null) {
      state = state.copyWith(isBusy: false, failure: failure);
      return false;
    }
    state = state.copyWith(isBusy: false, otpRequested: true);
    return true;
  }

  Future<bool> verifyOtp({
    required String phoneNumber,
    required String code,
    bool rememberMe = false,
  }) async {
    state = state.copyWith(isBusy: true, clearFailure: true);

    final result = await ref
        .read(verifyPhoneOtpUseCaseProvider)
        .call(phoneNumber: phoneNumber, code: code, rememberMe: rememberMe);

    return _applySignIn(result, rememberMe: rememberMe, identifier: phoneNumber);
  }

  Future<bool> _applySignIn(
    Result<AppUser> result, {
    required bool rememberMe,
    required String identifier,
  }) async {
    final user = result.valueOrNull;

    if (user == null) {
      state = state.copyWith(isBusy: false, failure: result.failureOrNull);
      return false;
    }

    state = state.copyWith(
      isAuthenticated: true,
      user: user,
      isBusy: false,
      clearFailure: true,
      otpRequested: false,
      rememberMe: rememberMe,
      savedIdentifier: rememberMe ? identifier : null,
    );

    // The policy must land before the router lets the user through: the first
    // frame after login would otherwise be computed against deny-all and the
    // redirect guard would bounce them straight back out.
    await ref.read(accessNotifierProvider.notifier).load(user.role);
    return true;
  }

  // ── sign out ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await ref.read(signOutUseCaseProvider).call();
    await _clearLocalSession();
  }

  /// Ends the session locally without calling the server. Used when the API has
  /// already said the session is gone (401), where a sign-out call would fail
  /// again with the same answer.
  Future<void> endSessionLocally() => _clearLocalSession();

  Future<void> _clearLocalSession() async {
    // Clear the token too: `signOut` already did via the repository, but the
    // 401 path reaches here without it and must not leave a dead bearer token
    // for the next request to replay.
    await ref.read(tokenStorageProvider).clearSession();
    await ref.read(accessNotifierProvider.notifier).clear();
    state = const AuthState.initial().copyWith(
      initialized: true,
      rememberMe: state.rememberMe,
      savedIdentifier: state.savedIdentifier,
    );
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// The signed-in user, or null. Convenience for the many widgets that need the
/// identity and not the whole state machine.
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authNotifierProvider).user;
});
