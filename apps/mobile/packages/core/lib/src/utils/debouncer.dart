import 'dart:async';

import '../constants/app_durations.dart';

/// Collapses a burst of calls into one, [delay] after the last.
///
/// Used for search-as-you-type and filter inputs so a keystroke does not become
/// a request.
class Debouncer {
  Debouncer({this.delay = AppDurations.searchDebounce});

  final Duration delay;
  Timer? _timer;

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Runs any pending action immediately (e.g. on submit).
  void flush(void Function() action) {
    _timer?.cancel();
    _timer = null;
    action();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
