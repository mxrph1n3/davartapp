import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    required this.hintText,
    required this.onTap,
    this.onFilterTap,
  });

  final String hintText;
  final VoidCallback onTap;
  final VoidCallback? onFilterTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: AppRadius.pillRadius,
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 22, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                hintText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
              ),
            ),
            if (onFilterTap != null)
              GestureDetector(
                onTap: onFilterTap,
                child: Icon(
                  Icons.tune,
                  size: 22,
                  color: colors.textPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
