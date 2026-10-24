import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

export 'app_colors.dart';
export 'app_motion.dart';
export 'app_radius.dart';
export 'app_shadows.dart';
export 'app_spacing.dart';
export 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light => _theme(Brightness.light);

  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colors = isDark ? DavartColors.dark : DavartColors.light;
    final textTheme = AppTypography.textTheme(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: <ThemeExtension<dynamic>>[colors],
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.accent,
        onPrimary: colors.textOnAccent,
        secondary: colors.textPrimary,
        onSecondary: colors.background,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        error: colors.error,
        onError: colors.background,
        outline: colors.border,
      ),
      textTheme: textTheme,
      iconTheme: IconThemeData(color: colors.textPrimary),
      // Text buttons («Вызов замерщика», «Изм.») — deep gold on white, yellow on black.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.accentText),
      ),
      dividerColor: colors.divider,
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
      ),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.textPrimary,
        strokeWidth: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? colors.surfaceMuted : colors.textPrimary,
        contentTextStyle: TextStyle(
          color: isDark ? colors.textPrimary : colors.background,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceMuted,
        selectedColor: colors.accent,
        disabledColor: colors.surfaceMuted,
        checkmarkColor: colors.textOnAccent,
        labelStyle: textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
        secondaryLabelStyle:
            textTheme.bodyMedium?.copyWith(color: colors.textOnAccent),
        side: BorderSide(color: colors.border),
        shape: const StadiumBorder(),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetRadius,
        ),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(color: colors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceMuted,
        hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textDisabled),
        labelStyle: textTheme.bodyMedium,
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: colors.textPrimary, width: 1.5),
        ),
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: colors.accentText,
        scaffoldBackgroundColor: colors.background,
        barBackgroundColor: colors.surface,
        textTheme: CupertinoTextThemeData(
          primaryColor: colors.textPrimary,
          textStyle: textTheme.bodyLarge,
          actionTextStyle: textTheme.bodyLarge?.copyWith(
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
