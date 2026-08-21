import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/tab_page.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../auth/presentation/require_login.dart';
import '../data/projects_models.dart';
import '../data/projects_repository.dart';
import 'projects_notifier.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  String? _statusFilter;

  Future<void> _createProject() async {
    if (!await promptLogin(context, ref)) return;
    if (!mounted) return;

    final nameController = TextEditingController();
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        var isSaving = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.screenPadding,
                right: AppSpacing.screenPadding,
                top: AppSpacing.screenPadding,
                bottom: MediaQuery.of(context).viewInsets.bottom +
                    AppSpacing.screenPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Новый проект',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppInput(
                    controller: nameController,
                    labelText: 'Название',
                    hintText: 'Например, Квартира на Арбате',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: 'Создать',
                    isLoading: isSaving,
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            if (name.isEmpty) return;
                            setModalState(() => isSaving = true);
                            try {
                              await ref
                                  .read(projectsRepositoryProvider)
                                  .createProject(name: name);
                              if (context.mounted) Navigator.pop(context, true);
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Не удалось создать проект'),
                                  ),
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                setModalState(() => isSaving = false);
                              }
                            }
                          },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    nameController.dispose();
    if (created == true) {
      ref.invalidate(projectsListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsListProvider);
    final showcaseAsync = ref.watch(showcaseProjectsProvider);

    return TabPage(
      child: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить проекты',
          onRetry: () => ref.invalidate(projectsListProvider),
        ),
        data: (projects) {
          final filtered = _statusFilter == null
              ? projects
              : projects.where((p) => p.status == _statusFilter).toList();
          final noOwnProjects = projects.isEmpty;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(projectsListProvider);
              ref.invalidate(showcaseProjectsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                ScreenHeader(
                  title: 'Проекты',
                  actions: [
                    HeaderIconButton(
                      icon: Icons.add,
                      onPressed: _createProject,
                    ),
                  ],
                ),
                if (!noOwnProjects) ...[
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        CategoryChip(
                          label: 'Все',
                          selected: _statusFilter == null,
                          onSelected: (_) =>
                              setState(() => _statusFilter = null),
                        ),
                        const SizedBox(width: 8),
                        CategoryChip(
                          label: 'В работе',
                          selected: _statusFilter == 'in_progress',
                          onSelected: (_) =>
                              setState(() => _statusFilter = 'in_progress'),
                        ),
                        const SizedBox(width: 8),
                        CategoryChip(
                          label: 'На паузе',
                          selected: _statusFilter == 'brief_filling',
                          onSelected: (_) =>
                              setState(() => _statusFilter = 'brief_filling'),
                        ),
                        const SizedBox(width: 8),
                        CategoryChip(
                          label: 'Завершённые',
                          selected: _statusFilter == 'completed',
                          onSelected: (_) =>
                              setState(() => _statusFilter = 'completed'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (noOwnProjects)
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 8),
                    child: ref.watch(authProvider).isAuthenticated
                        ? const EmptyState(
                            icon: Icons.folder_open_outlined,
                            title: 'Проектов пока нет',
                            subtitle:
                                'Когда вы обратитесь в студию, здесь появятся ваши проекты',
                          )
                        : EmptyState(
                            icon: Icons.folder_open_outlined,
                            title: 'Ваши проекты появятся здесь',
                            subtitle:
                                'Войдите по номеру, чтобы создать проект или увидеть свои',
                            actionLabel: 'Войти',
                            onAction: () => promptLogin(context, ref),
                          ),
                  )
                else if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Icons.folder_open_outlined,
                      title: 'Ничего не найдено',
                      subtitle: 'Попробуйте другой фильтр',
                    ),
                  )
                else
                  ...filtered.map(
                    (project) => ProjectCard(
                      compact: true,
                      name: project.name,
                      status: project.status,
                      statusLabel: project.statusLabel,
                      address: project.objectType ?? project.address,
                      coverUrl: projectCoverUrl(project.id),
                      onTap: () =>
                          context.push(AppRoutes.projectDetail(project.id)),
                    ),
                  ),
                if (noOwnProjects) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'А ниже вы можете ознакомиться с другими нашими проектами',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ..._showcaseSection(showcaseAsync),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _showcaseSection(AsyncValue<List<Project>> showcaseAsync) {
    return showcaseAsync.when(
      loading: () => [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (_, _) => [
        Text(
          'Не удалось загрузить примеры проектов',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
      data: (items) {
        if (items.isEmpty) {
          return [
            Text(
              'Скоро здесь появятся примеры работ',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ];
        }
        return items
            .map(
              (project) => ProjectCard(
                compact: true,
                name: project.name,
                status: project.status,
                statusLabel: project.objectType ?? project.statusLabel,
                address: [
                  if (project.objectType != null) project.objectType!,
                  if (project.area != null) '${project.area!.round()} м²',
                  if (project.style != null) project.style!,
                ].join(' · '),
                coverUrl: projectCoverUrl(project.id),
                onTap: () => context.push(
                  AppRoutes.projectDetail(project.id),
                ),
              ),
            )
            .toList();
      },
    );
  }
}
