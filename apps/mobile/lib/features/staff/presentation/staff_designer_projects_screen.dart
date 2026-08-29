import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/tab_page.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../projects/presentation/projects_notifier.dart';

class StaffDesignerProjectsScreen extends ConsumerStatefulWidget {
  const StaffDesignerProjectsScreen({super.key});

  @override
  ConsumerState<StaffDesignerProjectsScreen> createState() =>
      _StaffDesignerProjectsScreenState();
}

class _StaffDesignerProjectsScreenState
    extends ConsumerState<StaffDesignerProjectsScreen> {
  String _filter = 'in_progress';

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsListProvider);

    return TabPage(
      child: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить проекты',
          onRetry: () => ref.invalidate(projectsListProvider),
        ),
        data: (projects) {
          final visible = projects.where((project) {
            if (_filter == 'completed') {
              return project.status == 'completed' ||
                  project.status == 'archived';
            }
            // Active work: filling brief + in progress (not showcase — API excludes).
            return project.status != 'completed' &&
                project.status != 'archived';
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(projectsListProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                const ScreenHeader(title: 'Мои проекты'),
                Text(
                  'Объекты, на которые вас назначили',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    CategoryChip(
                      label: 'В работе',
                      selected: _filter == 'in_progress',
                      onSelected: (_) =>
                          setState(() => _filter = 'in_progress'),
                    ),
                    const SizedBox(width: 8),
                    CategoryChip(
                      label: 'Завершённые',
                      selected: _filter == 'completed',
                      onSelected: (_) => setState(() => _filter = 'completed'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (visible.isEmpty)
                  const EmptyState(
                    icon: Icons.folder_open_outlined,
                    title: 'Нет проектов',
                    subtitle:
                        'Когда комплектатор назначит вас на объект — он появится здесь',
                  )
                else
                  ...visible.map(
                    (project) => ProjectCard(
                      compact: true,
                      name: project.name,
                      status: project.status,
                      statusLabel: project.statusLabel,
                      address: [
                        if (project.objectType != null) project.objectType!,
                        if (project.address != null) project.address!,
                      ].join(' · '),
                      coverUrl: projectCoverUrl(project.id),
                      onTap: () => context.push(
                        AppRoutes.staffProjectWorkspace(project.id),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
