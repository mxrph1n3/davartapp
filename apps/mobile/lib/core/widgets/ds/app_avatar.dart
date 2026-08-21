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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: Text(
        avatarInitial(label),
        style: TextStyle(
          fontSize: label.trim().startsWith('+') || RegExp(r'^\d').hasMatch(label.trim())
              ? size * 0.28
              : size * 0.36,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
