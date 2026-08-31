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
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted ? colors.accent : colors.surfaceMuted,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(
          color: highlighted ? colors.accent : colors.border,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

bool isActiveProjectStatus(String label) {
  return label == 'Планировка' ||
      label == 'Замер' ||
      label == 'Бриф' ||
      label == 'Визуализация' ||
      label == 'В работе';
}

/// Colored status text for project list (matches design mockups).
Color projectStatusColor(String statusOrLabel, [DavartColors? colors]) {
  final c = colors ?? DavartColors.light;
  switch (statusOrLabel) {
    case 'in_progress':
    case 'Планировка':
    case 'В работе':
    case 'measurement':
    case 'Замер':
      return c.statusGold;
    case 'completed':
    case 'Завершён':
    case 'Завершен':
      return c.statusGreen;
    case 'brief_filling':
    case 'Бриф':
    case 'materials':
    case 'Ведомость материалов и мебели':
    case 'visualization':
    case 'Визуализация':
    case 'final_assembly':
    case 'Итоговые чертежи и сборка проекта':
    case 'archived':
    case 'Архив':
    default:
      return c.textSecondary;
  }
}

String projectCoverUrl(String projectId) {
  return 'https://picsum.photos/seed/davart-proj-$projectId/240/240';
}

String projectStageLabel(String status) {
  switch (status) {
    case 'brief_filling':
      return 'Бриф';
    case 'measurement':
      return 'Замер';
    case 'in_progress':
      return 'Планировка';
    case 'materials':
      return 'Ведомость материалов и мебели';
    case 'visualization':
      return 'Визуализация';
    case 'final_assembly':
      return 'Итоговые чертежи и сборка проекта';
    case 'completed':
      return 'Завершен';
    case 'archived':
      return 'Архив';
    default:
      return status;
  }
}

/// Client-side label: prefer stage from [status], map legacy API labels.
String resolveProjectStatusLabel({
  required String status,
  required String statusLabel,
}) {
  if (statusLabel == 'На паузе') return projectStageLabel('brief_filling');
  final fromStatus = projectStageLabel(status);
  if (fromStatus != status) return fromStatus;
  return statusLabel;
}

/// Hide stage on list cards while the brief is still being filled.
bool showProjectStatusOnList(String status) => status != 'brief_filling';

/// Deletable on brief stage (incl. legacy «На паузе» label from old API).
bool isProjectDeletable({required String status, required String statusLabel}) =>
    status == 'brief_filling' || statusLabel == 'На паузе';
