import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';

import '../notifiers/access_notifier.dart';

/// Which ward the parent shell is currently showing.
///
/// Every ward-scoped provider is `family`-keyed on this, so switching children
/// never leaks one sibling's cached data under another. Persisted, because a
/// guardian with one ward should never see a picker and a guardian with three
/// should not re-pick on every launch.
class SelectedWardNotifier extends Notifier<String?> {
  static const _key = 'najath.selected_ward';

  @override
  String? build() {
    final wards = ref.watch(accessNotifierProvider).scopes.wardIds;

    // A single ward is not a choice. Skip the switcher entirely.
    if (wards.length == 1) return wards.first;

    unawaited(_restore(wards));
    return null;
  }

  Future<void> _restore(Set<String> wards) async {
    final stored = await ref.read(secureStorageProvider).read(key: _key);
    // Only honour it if the guardianship still holds — a ward can be
    // transferred, and a stale id must not keep resolving.
    if (stored != null && wards.contains(stored)) state = stored;
  }

  Future<void> select(String studentId) async {
    state = studentId;
    await ref.read(secureStorageProvider).write(key: _key, value: studentId);
  }

  Future<void> clear() async {
    state = null;
    await ref.read(secureStorageProvider).delete(key: _key);
  }
}

final selectedWardProvider = NotifierProvider<SelectedWardNotifier, String?>(
  SelectedWardNotifier.new,
);
