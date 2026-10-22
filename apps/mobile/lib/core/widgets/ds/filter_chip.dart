import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // Flutter 3.44 does not apply ChipTheme.secondaryLabelStyle to a selected
    // FilterChip, so the label color has to be set on this chip itself.
    final labelStyle = TextStyle(
      fontSize: 14,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      color: selected ? AppColors.textOnAccent : colors.textSecondary,
    );
    return FilterChip(
      label: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: labelStyle,
      ),
      labelStyle: labelStyle,
      selected: selected,
      showCheckmark: false,
      onSelected: onSelected,
      selectedColor: colors.accent,
      backgroundColor: Colors.transparent,
      disabledColor: Colors.transparent,
      shadowColor: Colors.transparent,
      selectedShadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      pressElevation: 0,
      side: BorderSide(color: colors.border),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillRadius),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class ActiveFilterChip extends StatelessWidget {
  const ActiveFilterChip({
    super.key,
    required this.label,
    required this.onDeleted,
  });

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          IconButton(
            onPressed: onDeleted,
            icon: const Icon(Icons.close, size: 16),
            color: colors.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
