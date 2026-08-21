import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../documents/presentation/project_documents_section.dart';
import '../data/projects_models.dart';
import '../data/projects_repository.dart';
import 'brief_answers_view.dart';
import 'projects_notifier.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectDetailProvider(projectId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => popOrGo(
            context,
            projectsPathForRole(ref.watch(authProvider).user?.role),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {},
          ),
        ],
      ),
      body: projectAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить проект',
          onRetry: () => ref.invalidate(projectDetailProvider(projectId)),
        ),
        data: (project) {
          return DefaultTabController(
            length: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    0,
                    AppSpacing.screenPadding,
                    AppSpacing.md,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          project.name,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      StatusBadge(
                        label: project.statusLabel,
                        highlighted: project.status == 'in_progress',
                      ),
                    ],
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  unselectedLabelStyle: Theme.of(context).textTheme.bodyLarge,
                  indicatorColor: AppColors.textPrimary,
                  indicatorWeight: 2.5,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: AppColors.divider,
                  tabs: const [
                    Tab(text: 'Общая информация'),
                    Tab(text: 'Анкета'),
                    Tab(text: 'Документы'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _GeneralInfoTab(project: project, projectId: projectId),
                      _BriefTab(project: project, projectId: projectId),
                      ListView(
                        padding: const EdgeInsets.all(AppSpacing.screenPadding),
                        children: [
                          ProjectDocumentsSection(projectId: projectId),
                        ],
                      ),
                    ],
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

class _GeneralInfoTab extends ConsumerWidget {
  const _GeneralInfoTab({required this.project, required this.projectId});

  final Project project;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final description = project.brief?.wishes;
    final membersAsync = project.isShowcase
        ? null
        : ref.watch(projectMembersProvider(projectId));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        AppSpacing.xl,
      ),
      children: [
        if (project.objectType != null)
          _DetailRow(label: 'Тип объекта', value: project.objectType!),
        if (project.address != null)
          _DetailRow(label: 'Адрес', value: project.address!),
        if (project.area != null)
          _DetailRow(label: 'Площадь', value: '${project.area!.round()} м²'),
        if (project.style != null)
          _DetailRow(label: 'Стиль', value: project.style!),
        _DetailRow(label: 'Этап', value: projectStageLabel(project.status)),
        if (project.manager != null)
          _DetailRow(
            label: 'Менеджер',
            value: project.manager!.name,
            trailing: AppAvatar(label: project.manager!.name, size: 28),
          ),
        if (project.designer != null)
          _DetailRow(
            label: 'Дизайнер',
            value: project.designer!.name,
            trailing: AppAvatar(label: project.designer!.name, size: 28),
          ),
        if (project.surveyor != null)
          _DetailRow(
            label: 'Замерщик',
            value: project.surveyor!.name,
            trailing: AppAvatar(label: project.surveyor!.name, size: 28),
          ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Описание',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.45,
                  color: AppColors.textPrimary,
                ),
          ),
        ],
        if (membersAsync != null) ...[
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Участники',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              TextButton(
                onPressed: () => _inviteMember(context, ref),
                child: const Text('Добавить'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          membersAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => Text(
              'Не удалось загрузить участников',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            data: (members) {
              if (members.isEmpty) {
                return Text(
                  'Пока только вы',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                );
              }
              return Column(
                children: members
                    .map(
                      (m) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: AppAvatar(label: m.user.displayName, size: 36),
                        title: Text(m.user.displayName),
                        subtitle: Text('${m.roleLabel} · ${m.user.phone}'),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ],
    );
  }

  Future<void> _inviteMember(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Добавить участника'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Телефон',
              hintText: '+79001234567',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );

    if (phone == null || phone.isEmpty) return;

    try {
      await ref.read(projectsRepositoryProvider).inviteMember(
            projectId: projectId,
            phone: phone,
          );
      ref.invalidate(projectMembersProvider(projectId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Участник добавлен')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось добавить участника')),
        );
      }
    }
  }
}

class _BriefTab extends StatelessWidget {
  const _BriefTab({required this.project, required this.projectId});

  final Project project;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final brief = project.brief;
    final hasContent = brief != null && briefHasFilledContent(brief);

    if (!hasContent) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PrimaryButton(
              label: 'Перейти к анкете',
              onPressed: () => context.push(AppRoutes.projectBrief(projectId)),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        AppSpacing.xl,
      ),
      children: [
        if (brief.isLocked)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Анкета заблокирована — проект в работе',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        BriefAnswersView(brief: brief),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: brief.isLocked ? 'Открыть анкету' : 'Продолжить анкету',
          onPressed: () => context.push(AppRoutes.projectBrief(projectId)),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}
