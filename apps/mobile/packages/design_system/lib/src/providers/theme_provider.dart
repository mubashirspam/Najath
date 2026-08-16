import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';

/// The user's theme choice, restored from secure storage at first read and
/// persisted on every change.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Start on the platform setting and correct it once storage answers, so the
    // first frame is never blocked on a keystore read.
    unawaited(_restore());
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    final stored = await ref.read(tokenStorageProvider).getThemeMode();
    if (stored != state) state = stored;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(tokenStorageProvider).saveThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
