import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../commerce/presentation/active_project_provider.dart';
import '../../commerce/presentation/project_picker_sheet.dart';
import 'working_client_provider.dart';

/// Persistent strip: whose project cart catalog actions target.
class WorkingClientBanner extends ConsumerWidget {
  const WorkingClientBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final working = ref.watch(workingClientProvider);
    final project = ref.watch(activeProjectProvider);
    if (working == null) return const SizedBox.shrink();

    final label = project != null
        ? 'Корзина проекта: ${project.name}'
        : 'Клиент: ${working.displayName} — выберите проект';

    return Material(
      color: colors.accent.withValues(alpha: 0.35),
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: () async {
            if (project != null) {
              context.push(AppRoutes.staffProjectCart(project.id));
              return;
            }
            final picked = await ensureActiveProject(
              context,
              ref,
              staffClientId: working.id,
              forcePicker: true,
            );
            if (picked != null && context.mounted) {
              context.push(AppRoutes.staffProjectCart(picked));
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: 10,
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, size: 18),
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
                TextButton(
                  onPressed: () async {
                    final picked = await ensureActiveProject(
                      context,
                      ref,
                      staffClientId: working.id,
                      forcePicker: true,
                    );
                    if (picked != null && context.mounted) {
                      context.push(AppRoutes.staffProjectCart(picked));
                    }
                  },
                  child: Text(project == null ? 'Проект' : 'Открыть'),
                ),
                IconButton(
                  tooltip: 'Сбросить',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    ref.read(workingClientProvider.notifier).state = null;
                    ref.read(activeProjectProvider.notifier).state = null;
                  },
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
