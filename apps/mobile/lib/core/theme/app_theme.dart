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

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.accent,
        onPrimary: AppColors.textOnAccent,
        secondary: AppColors.textPrimary,
        onSecondary: AppColors.background,
        surface: isDark ? AppColors.darkSurface : AppColors.surface,
        onSurface: isDark ? AppColors.background : AppColors.textPrimary,
        error: AppColors.error,
        onError: AppColors.background,
        outline: AppColors.border,
      ),
      textTheme: AppTypography.textTheme,
      dividerColor: AppColors.divider,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.background,
        foregroundColor:
            isDark ? AppColors.background : AppColors.textPrimary,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: AppTypography.textTheme.titleLarge,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.textPrimary,
        strokeWidth: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: AppColors.background),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetRadius),
        elevation: 0,
      ),
    );
  }
}
