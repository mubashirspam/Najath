import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_network/najath_network.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

/// Staff sign-in.
class SignInWithEmailUseCase {
  const SignInWithEmailUseCase(this._repository);

  final AuthRepository _repository;

  Future<ApiResponse<AppUser>> call({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final result = await _repository.signInWithEmail(
      email: email.trim(),
      password: password,
    );
    if (result.hasData) {
      await _repository.saveRememberMe(
        remember: rememberMe,
        identifier: email.trim(),
      );
    }
    return result;
  }
}

/// Sends a guardian's one-time code.
class RequestPhoneOtpUseCase {
  const RequestPhoneOtpUseCase(this._repository);

  final AuthRepository _repository;

  Future<ApiResponse<void>> call(String phoneNumber) =>
      _repository.requestPhoneOtp(_normalise(phoneNumber));
}

/// Exchanges a guardian's code for a session.
class VerifyPhoneOtpUseCase {
  const VerifyPhoneOtpUseCase(this._repository);

  final AuthRepository _repository;

  Future<ApiResponse<AppUser>> call({
    required String phoneNumber,
    required String code,
    bool rememberMe = false,
  }) async {
    final normalised = _normalise(phoneNumber);
    final result = await _repository.verifyPhoneOtp(
      phoneNumber: normalised,
      code: code.trim(),
    );
    if (result.hasData) {
      await _repository.saveRememberMe(
        remember: rememberMe,
        identifier: normalised,
      );
    }
    return result;
  }
}

class SignOutUseCase {
  const SignOutUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.signOut();
}

/// Strips formatting and defaults to the academy's country code.
///
/// Guardians type their number every way imaginable — `0904 812 3456`,
/// `+91 90481 23456`, `9048123456`. Better Auth matches the stored value
/// exactly, so normalising here is what makes OTP login work at all.
String _normalise(String phoneNumber) {
  var digits = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.startsWith('+')) return digits;
  digits = digits.replaceFirst(RegExp('^0+'), '');
  if (digits.length == 10) return '+91$digits';
  return '+$digits';
}

final signInWithEmailUseCaseProvider = Provider<SignInWithEmailUseCase>((ref) {
  return SignInWithEmailUseCase(ref.watch(authRepositoryProvider));
});

final requestPhoneOtpUseCaseProvider = Provider<RequestPhoneOtpUseCase>((ref) {
  return RequestPhoneOtpUseCase(ref.watch(authRepositoryProvider));
});

final verifyPhoneOtpUseCaseProvider = Provider<VerifyPhoneOtpUseCase>((ref) {
  return VerifyPhoneOtpUseCase(ref.watch(authRepositoryProvider));
});

final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) {
  return SignOutUseCase(ref.watch(authRepositoryProvider));
});
