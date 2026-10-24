import 'package:flutter/material.dart';

/// Brand / semantic colors resolved for the active brightness.
///
/// Prefer [AppColors.of] in widgets. Static [AppColors] fields remain the
/// light palette for splash and non-[BuildContext] call sites.
@immutable
class DavartColors extends ThemeExtension<DavartColors> {
  const DavartColors({
    required this.accent,
    required this.accentPressed,
    required this.accentText,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.textOnAccent,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.imagePlaceholder,
    required this.divider,
    required this.border,
    required this.error,
    required this.brandDark,
    required this.statusGold,
    required this.statusGreen,
    required this.chatBubbleMine,
    required this.chatBubbleMineFg,
    required this.chatBubbleTheirs,
  });

  final Color accent;
  final Color accentPressed;

  /// Brand yellow for text and icons on dark; on white it is unreadable, so black there.
  /// The yellow itself is the brand colour and is never replaced by another hue.
  final Color accentText;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color textOnAccent;
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color imagePlaceholder;
  final Color divider;
  final Color border;
  final Color error;
  final Color brandDark;
  final Color statusGold;
  final Color statusGreen;
  final Color chatBubbleMine;
  final Color chatBubbleMineFg;
  final Color chatBubbleTheirs;

  static const light = DavartColors(
    accent: Color(0xFFFFDD2D),
    accentPressed: Color(0xFFF5D420),
    accentText: Color(0xFF111111),
    textPrimary: Color(0xFF111111),
    textSecondary: Color(0x8C111111),
    textDisabled: Color(0x40111111),
    textOnAccent: Color(0xFF111111),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF7F7F7),
    imagePlaceholder: Color(0xFFF2F2F2),
    divider: Color(0x14111111),
    border: Color(0x14111111),
    error: Color(0xFFE53935),
    brandDark: Color(0xFF111111),
    statusGold: Color(0xFFD4A800),
    statusGreen: Color(0xFF5BB89A),
    chatBubbleMine: Color(0xFFEFFDDE),
    chatBubbleMineFg: Color(0xFF111111),
    chatBubbleTheirs: Color(0xFFF7F7F7),
  );

  static const dark = DavartColors(
    accent: Color(0xFFFFDD2D),
    accentPressed: Color(0xFFF5D420),
    accentText: Color(0xFFFFDD2D),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0x8CF5F5F5),
    textDisabled: Color(0x40F5F5F5),
    textOnAccent: Color(0xFF111111),
    background: Color(0xFF111111),
    surface: Color(0xFF1A1A1A),
    surfaceMuted: Color(0xFF242424),
    imagePlaceholder: Color(0xFF2A2A2A),
    divider: Color(0x24FFFFFF),
    border: Color(0x24FFFFFF),
    error: Color(0xFFEF5350),
    brandDark: Color(0xFF111111),
    statusGold: Color(0xFFE0B84A),
    statusGreen: Color(0xFF6BC9A8),
    chatBubbleMine: Color(0xFF2B5278),
    chatBubbleMineFg: Color(0xFFFFFFFF),
    chatBubbleTheirs: Color(0xFF182533),
  );

  static DavartColors of(BuildContext context) {
    return Theme.of(context).extension<DavartColors>() ?? light;
  }

  @override
  DavartColors copyWith({
    Color? accent,
    Color? accentPressed,
    Color? accentText,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? textOnAccent,
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? imagePlaceholder,
    Color? divider,
    Color? border,
    Color? error,
    Color? brandDark,
    Color? statusGold,
    Color? statusGreen,
    Color? chatBubbleMine,
    Color? chatBubbleMineFg,
    Color? chatBubbleTheirs,
  }) {
    return DavartColors(
      accent: accent ?? this.accent,
      accentPressed: accentPressed ?? this.accentPressed,
      accentText: accentText ?? this.accentText,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      textOnAccent: textOnAccent ?? this.textOnAccent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      imagePlaceholder: imagePlaceholder ?? this.imagePlaceholder,
      divider: divider ?? this.divider,
      border: border ?? this.border,
      error: error ?? this.error,
      brandDark: brandDark ?? this.brandDark,
      statusGold: statusGold ?? this.statusGold,
      statusGreen: statusGreen ?? this.statusGreen,
      chatBubbleMine: chatBubbleMine ?? this.chatBubbleMine,
      chatBubbleMineFg: chatBubbleMineFg ?? this.chatBubbleMineFg,
      chatBubbleTheirs: chatBubbleTheirs ?? this.chatBubbleTheirs,
    );
  }

  @override
  DavartColors lerp(ThemeExtension<DavartColors>? other, double t) {
    if (other is! DavartColors) return this;
    return DavartColors(
      accent: Color.lerp(accent, other.accent, t)!,
      accentPressed: Color.lerp(accentPressed, other.accentPressed, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textOnAccent: Color.lerp(textOnAccent, other.textOnAccent, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      border: Color.lerp(border, other.border, t)!,
      imagePlaceholder:
          Color.lerp(imagePlaceholder, other.imagePlaceholder, t)!,
      error: Color.lerp(error, other.error, t)!,
      brandDark: Color.lerp(brandDark, other.brandDark, t)!,
      statusGold: Color.lerp(statusGold, other.statusGold, t)!,
      statusGreen: Color.lerp(statusGreen, other.statusGreen, t)!,
      chatBubbleMine: Color.lerp(chatBubbleMine, other.chatBubbleMine, t)!,
      chatBubbleMineFg:
          Color.lerp(chatBubbleMineFg, other.chatBubbleMineFg, t)!,
      chatBubbleTheirs:
          Color.lerp(chatBubbleTheirs, other.chatBubbleTheirs, t)!,
    );
  }
}

/// Premium minimal palette — single accent, neutral text scale.
///
/// Static fields are the **light** palette (splash / const). In widgets use
/// [AppColors.of] so dark mode resolves correctly.
abstract final class AppColors {
  static DavartColors of(BuildContext context) => DavartColors.of(context);

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

  static const brandDark = Color(0xFF111111);

  static const darkBackground = Color(0xFF111111);
  static const darkSurface = Color(0xFF1A1A1A);
}
