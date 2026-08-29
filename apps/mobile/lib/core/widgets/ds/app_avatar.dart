import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../utils/avatar_initial.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.label,
    this.size = 72,
  });

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final initial = avatarInitial(label);
    final showSilhouette = initial.isEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        shape: BoxShape.circle,
        border: Border.all(color: colors.border),
      ),
      alignment: Alignment.center,
      child: showSilhouette
          ? Icon(
              Icons.person_outline,
              size: size * 0.5,
              color: colors.textSecondary,
            )
          : Text(
              initial,
              style: TextStyle(
                fontSize: label.trim().startsWith('+') ||
                        RegExp(r'^\d').hasMatch(label.trim())
                    ? size * 0.28
                    : size * 0.36,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
    );
  }
}
