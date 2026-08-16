import 'package:flutter/material.dart';

/// Brand palette.
///
/// An explicit `ColorScheme` rather than `ColorScheme.fromSeed`: the academy's
/// green is a fixed brand colour and seed generation would drift it between
/// Flutter releases.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0F6E4F);
  static const Color primaryDark = Color(0xFF0A4E38);
  static const Color primaryLight = Color(0xFF3D9B78);

  static const Color accent = Color(0xFFC9A227);
  static const Color accentDark = Color(0xFF8F7318);

  static const Color success = Color(0xFF1E8E3E);
  static const Color warning = Color(0xFFB26B00);
  static const Color danger = Color(0xFFC5221F);
  static const Color info = Color(0xFF1A73E8);

  /// Attendance states, reused by the roster chips, the calendar and charts so
  /// one status never reads as two different colours.
  static const Color present = success;
  static const Color absent = danger;
  static const Color late = warning;
  static const Color excused = info;

  static const Color lightSurface = Color(0xFFFCFCFA);
  static const Color lightBackground = Color(0xFFF4F5F2);
  static const Color darkSurface = Color(0xFF15181A);
  static const Color darkBackground = Color(0xFF0E1012);

  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFCDEBDD),
    onPrimaryContainer: primaryDark,
    secondary: accent,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFF6EBC6),
    onSecondaryContainer: accentDark,
    error: danger,
    onError: Colors.white,
    surface: lightSurface,
    onSurface: Color(0xFF1A1C1B),
    surfaceContainerHighest: Color(0xFFE6E9E5),
    onSurfaceVariant: Color(0xFF44483F),
    outline: Color(0xFF757970),
  );

  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: primaryLight,
    onPrimary: Color(0xFF00382A),
    primaryContainer: primaryDark,
    onPrimaryContainer: Color(0xFFCDEBDD),
    secondary: Color(0xFFDCC671),
    onSecondary: Color(0xFF3B2F00),
    secondaryContainer: accentDark,
    onSecondaryContainer: Color(0xFFF6EBC6),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    surface: darkSurface,
    onSurface: Color(0xFFE2E3DE),
    surfaceContainerHighest: Color(0xFF2A2E2C),
    onSurfaceVariant: Color(0xFFC3C8BE),
    outline: Color(0xFF8D9289),
  );
}
