import 'package:flutter/material.dart';

import '../responsive/breakpoints.dart';

extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;

  Size get screenSize => MediaQuery.sizeOf(this);
  ScreenType get screenType => screenTypeOf(this);
  bool get isMobile => screenType == ScreenType.mobile;
  bool get isTablet => screenType == ScreenType.tablet;
  bool get isDesktop => screenType == ScreenType.desktop;

  /// True when the active locale renders right-to-left — the Arabic and Urdu
  /// surfaces the academy needs.
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;

  void showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? colors.error : null,
        ),
      );
  }
}
