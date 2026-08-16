import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Raw connectivity events from the platform, seeded with the current state so
/// the first read is not null.
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) async* {
  final connectivity = Connectivity();
  yield await connectivity.checkConnectivity();
  yield* connectivity.onConnectivityChanged;
});

/// Whether the device currently has any network transport.
///
/// Optimistically `true` until the first event arrives so startup never blocks
/// on connectivity. This is a transport check, not a reachability check — the
/// sync engine and the write outbox both re-verify by actually trying.
final isOnlineProvider = Provider<bool>((ref) {
  final results = ref.watch(connectivityStreamProvider).value;
  if (results == null) return true;
  return results.any((r) => r != ConnectivityResult.none);
});
