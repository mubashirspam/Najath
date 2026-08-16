import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_network/najath_network.dart';

import '../notifiers/access_notifier.dart';
import '../notifiers/auth_notifier.dart';

/// Connects the transport layer's 401/403 signals to the session and policy
/// notifiers.
///
/// `najath_network` cannot import `najath_auth` — the dependency runs the other
/// way — so `DioClient` exposes callbacks and this is where they are filled in.
/// Watched once during bootstrap.
final authHooksProvider = Provider<void>((ref) {
  final hooks = ref.watch(dioClientHooksProvider);

  // The receiver is "duplicated" only because the teardown below needs the same
  // instance; folding them into one cascade is not possible across a closure.
  // ignore: cascade_invocations
  hooks
    ..onUnauthorized = () {
      // The server says the session is gone. Ending it locally is enough — a
      // sign-out call would only fail with the same 401.
      unawaited(ref.read(authNotifierProvider.notifier).endSessionLocally());
    }
    ..onForbidden = () {
      // The UI offered something the server refused, which means the cached
      // policy is behind the admin console. Refetch so the affordance
      // disappears instead of failing again on the next tap.
      unawaited(ref.read(accessNotifierProvider.notifier).refresh());
    };

  ref.onDispose(() {
    hooks
      ..onUnauthorized = null
      ..onForbidden = null;
  });
});
