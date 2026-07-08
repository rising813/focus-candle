import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color background   = Color(0xFF0A0A0A);
  static const Color surface      = Color(0xFF141414);
  static const Color flameCore    = Color(0xFFFFFFE8);
  static const Color flameInner   = Color(0xFFFFF0A0);
  static const Color flameMid     = Color(0xFFFFB340);
  static const Color flameOuter   = Color(0xFFE8621A);
  static const Color glowWarm     = Color(0xFFFF8C1A);
  static const Color waxTop       = Color(0xFFD4BFA0);
  static const Color waxBody      = Color(0xFFBFA882);
  static const Color waxShadow    = Color(0xFF7A6A52);
  static const Color waxHighlight = Color(0xFFEDD9B8);
  static const Color textPrimary  = Color(0xFFEDE6D6);
  static const Color textMuted    = Color(0xFF5A5248);
  static const Color textDim      = Color(0xFF3A3228);
  static const Color separator    = Color(0xFF1E1A16);

  // ── Typography ────────────────────────────────────────────────────────────
  static const TextStyle timerStyle = TextStyle(
    fontFamily: 'Georgia',
    fontSize: 68,
    fontWeight: FontWeight.w400,
    letterSpacing: 4,
    color: textPrimary,
    height: 1.0,
  );

  static const TextStyle labelStyle = TextStyle(
    fontFamily: 'Georgia',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 5,
    color: textMuted,
  );

  static const TextStyle buttonStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 3,
    color: textPrimary,
  );

  static const TextStyle settingLabelStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 1,
    color: textPrimary,
  );

  static const TextStyle settingValueStyle = TextStyle(
    fontFamily: 'Georgia',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 1,
    color: flameMid,
  );

  // ── ThemeData ─────────────────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      surface: surface,
      primary: flameMid,
      onSurface: textPrimary,
    ),
    useMaterial3: true,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
