/// Authentication and authorisation.
///
/// Staff sign in with email and password, guardians with a phone OTP. Both end
/// up with a bearer token and an access policy — the role → screen matrix the
/// admin console controls — cached so the app stays correctly restricted
/// offline.
library;

export 'src/data/models/access_policy_dto.dart';
export 'src/data/models/app_user_dto.dart';
export 'src/data/repositories/access_repository_impl.dart';
export 'src/data/repositories/auth_repository_impl.dart';
export 'src/domain/entities/app_user.dart';
export 'src/domain/repositories/auth_repository.dart';
export 'src/domain/use_cases/sign_in_use_cases.dart';
export 'src/presentation/notifiers/access_notifier.dart';
export 'src/presentation/notifiers/auth_notifier.dart';
export 'src/presentation/providers/access_providers.dart';
export 'src/presentation/providers/auth_hooks.dart';
