import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import 'primary_button.dart';

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.children,
    this.padding,
  });

  final List<Widget> children;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ??
          EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.md,
            AppSpacing.screenPadding,
            AppSpacing.md + MediaQuery.paddingOf(context).bottom,
          ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(children: children),
    );
  }
}

class BottomActionBarButton extends StatelessWidget {
  const BottomActionBarButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    if (leading != null) {
      return Expanded(
        child: Row(
          children: [
            leading!,
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: PrimaryButton(label: label, onPressed: onPressed),
            ),
          ],
        ),
      );
    }
    return Expanded(
      child: PrimaryButton(label: label, onPressed: onPressed),
    );
  }
}

class IconActionButton extends StatelessWidget {
  const IconActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : AppColors.surfaceMuted,
      borderRadius: AppRadius.buttonRadius,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.buttonRadius,
        child: Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.buttonRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            icon,
            size: 22,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
