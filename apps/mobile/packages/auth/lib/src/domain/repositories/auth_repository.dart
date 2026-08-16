import 'package:najath_core/najath_core.dart';
import 'package:najath_network/najath_network.dart';

import '../entities/app_user.dart';

/// What the presentation layer is allowed to ask of authentication.
///
/// Abstract so the notifier can be tested against a fake without a Dio stack,
/// and so a future migration off Better Auth is a data-layer change only.
abstract class AuthRepository {
  /// Staff sign-in. Guardians have no password — see [requestPhoneOtp].
  Future<ApiResponse<AppUser>> signInWithEmail({
    required String email,
    required String password,
  });

  /// Sends a one-time code to a guardian's registered number.
  Future<ApiResponse<void>> requestPhoneOtp(String phoneNumber);

  Future<ApiResponse<AppUser>> verifyPhoneOtp({
    required String phoneNumber,
    required String code,
  });

  /// Reads the session back from the server, refreshing the cached user.
  /// Returns an [ApiError] rather than throwing when offline, so a relaunch on
  /// a plane keeps the stored session instead of signing the user out.
  Future<ApiResponse<AppUser>> currentSession();

  /// The user persisted at last sign-in, available with no network at all.
  Future<AppUser?> cachedUser();

  Future<bool> hasStoredSession();

  Future<void> signOut();

  Future<void> saveRememberMe({required bool remember, String? identifier});
  Future<bool> getRememberMe();
  Future<String?> savedIdentifier();
}

/// The role → screen policy, resolved server-side from the matrix the admin
/// console edits.
abstract class AccessRepository {
  /// Cached policy, or null if none has ever been stored.
  Future<AccessPolicy?> cached();

  /// Fetches from the server and persists. On failure returns the error; the
  /// caller decides whether to fall back to [cached].
  Future<ApiResponse<AccessPolicy>> fetch();

  Future<void> clear();

  /// Whether the cached policy is old enough to be worth refreshing while
  /// online. Offline the cached policy is used regardless of age.
  Future<bool> isStale();
}
