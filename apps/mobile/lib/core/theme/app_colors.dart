import 'package:flutter/material.dart';

/// Premium minimal palette — single accent, neutral text scale.
abstract final class AppColors {
  static const accent = Color(0xFFFFDD2D);
  static const accentPressed = Color(0xFFF5D420);

  static const textPrimary = Color(0xFF111111);
  static const textSecondary = Color(0x8C111111); // 55%
  static const textDisabled = Color(0x40111111); // 25%
  static const textOnAccent = Color(0xFF111111);

  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF7F7F7);
  static const imagePlaceholder = Color(0xFFF2F2F2);

  static const divider = Color(0x14111111); // 8%
  static const border = Color(0x14111111);

  static const error = Color(0xFFE53935);

  // Splash / brand moment
  static const brandDark = Color(0xFF111111);

  // Dark mode (kept minimal)
  static const darkBackground = Color(0xFF111111);
  static const darkSurface = Color(0xFF1A1A1A);
}
