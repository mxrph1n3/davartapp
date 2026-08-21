import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.highlighted = false,
  });

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.accent : AppColors.surfaceMuted,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(
          color: highlighted ? AppColors.accent : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

bool isActiveProjectStatus(String label) {
  return label == 'В работе' ||
      label == 'Заполнение брифа' ||
      label == 'На паузе';
}

/// Colored status text for project list (matches design mockups).
Color projectStatusColor(String statusOrLabel) {
  switch (statusOrLabel) {
    case 'in_progress':
    case 'В работе':
      return const Color(0xFFD4A800);
    case 'completed':
    case 'Завершён':
    case 'Завершен':
      return const Color(0xFF5BB89A);
    case 'brief_filling':
    case 'На паузе':
    case 'Заполнение брифа':
    case 'archived':
    case 'Архив':
    default:
      return AppColors.textSecondary;
  }
}

String projectCoverUrl(String projectId) {
  return 'https://picsum.photos/seed/davart-proj-$projectId/240/240';
}

String projectStageLabel(String status) {
  switch (status) {
    case 'brief_filling':
      return 'Бриф';
    case 'in_progress':
      return 'Планировка';
    case 'completed':
      return 'Сдача';
    case 'archived':
      return 'Архив';
    default:
      return status;
  }
}
