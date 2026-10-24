import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'active_project_provider.dart';
import 'project_picker_sheet.dart';

/// Client strip: which project cart is active (Samokat-style switcher).
class ProjectCartBanner extends ConsumerWidget {
  const ProjectCartBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final project = ref.watch(activeProjectProvider);
    final label = project == null
        ? 'Выберите проект для корзины'
        : 'Корзина проекта: ${project.name}';

    return Material(
      color: colors.surfaceMuted,
      child: InkWell(
        onTap: () => ensureActiveProject(
          context,
          ref,
          forcePicker: true,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: 10,
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Сменить',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.accentText,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
