import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/ru_phone_input_formatter.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../documents/presentation/project_documents_section.dart';
import '../data/projects_models.dart';
import '../data/projects_repository.dart';
import '../data/project_summary.dart';
import 'brief_answers_view.dart';
import 'projects_notifier.dart';
import 'surveyor_request.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final projectAsync = ref.watch(projectDetailProvider(projectId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
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
          if (project.isShowcase) {
            return DefaultTabController(
              length: 2,
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
                          child: Builder(
                            builder: (context) {
                              final colors = AppColors.of(context);
                              final summary = projectBriefSummary(project);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    project.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  if (summary != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      summary,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: colors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        StatusBadge(
                          label: resolveProjectStatusLabel(
                            status: project.status,
                            statusLabel: project.statusLabel,
                          ),
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
                    labelColor: colors.textPrimary,
                    unselectedLabelColor: colors.textSecondary,
                    labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    unselectedLabelStyle: Theme.of(context).textTheme.bodyLarge,
                    indicatorColor: colors.textPrimary,
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: colors.divider,
                    tabs: const [
                      Tab(text: 'Общая информация'),
                      Tab(text: 'Документы'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _GeneralInfoTab(project: project, projectId: projectId),
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
          }

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
                        child: Builder(
                          builder: (context) {
                            final colors = AppColors.of(context);
                            final summary = projectBriefSummary(project);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  project.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                if (summary != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    summary,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatusBadge(
                            label: resolveProjectStatusLabel(
                              status: project.status,
                              statusLabel: project.statusLabel,
                            ),
                            highlighted: project.status == 'in_progress' ||
                                project.status == 'measurement',
                          ),
                          if (!project.isShowcase &&
                              (project.status == 'brief_filling' ||
                                  project.status == 'measurement')) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => requestSurveyorConfirm(
                                context,
                                ref,
                                projectId,
                              ),
                              child: const Text('Вызов замерщика'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  labelColor: colors.textPrimary,
                  unselectedLabelColor: colors.textSecondary,
                  labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  unselectedLabelStyle: Theme.of(context).textTheme.bodyLarge,
                  indicatorColor: colors.textPrimary,
                  indicatorWeight: 2.5,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: colors.divider,
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
    final colors = AppColors.of(context);
    final membersAsync = project.isShowcase
        ? null
        : ref.watch(projectMembersProvider(projectId));
    final objectType = projectObjectTypeLabel(project);
    final address = projectAddressValue(project);
    final area = projectAreaValue(project);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        AppSpacing.xl,
      ),
      children: [
        if (objectType != null)
          _DetailRow(label: 'Тип объекта', value: objectType),
        if (address != null) _DetailRow(label: 'Адрес', value: address),
        const _DetailRow(label: 'Тип проекта', value: 'Полный проект'),
        if (area != null)
          _DetailRow(label: 'Площадь', value: '${area.round()} м²'),
        if (membersAsync != null) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Участники',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
                        color: colors.textSecondary,
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
                        subtitle: m.participantSubtitle != null
                            ? Text(
                                m.participantSubtitle!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colors.textSecondary,
                                    ),
                              )
                            : null,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _DashedAddMemberButton(
            onPressed: () => _inviteMember(context, ref),
          ),
        ],
      ],
    );
  }

  Future<void> _inviteMember(BuildContext context, WidgetRef ref) async {
    final phoneController = TextEditingController(text: '+7');
    final nameController = TextEditingController();
    var relation = 'relative';
    var errorText = '';
    final result = await showDialog<({String phone, String name, String relation})>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Добавить участника'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        const RuPhoneInputFormatter(),
                        LengthLimitingTextInputFormatter(12),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Телефон',
                        hintText: '+7XXXXXXXXXX',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Имя',
                        hintText: 'Как зовут',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Кем приходится',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final choice in const [
                          ('partner', 'Супруг'),
                          ('child', 'Ребёнок'),
                          ('parent', 'Родитель'),
                          ('relative', 'Родственник'),
                          ('other', 'Другой'),
                        ])
                          ChoiceChip(
                            label: Text(
                              choice.$2,
                              style: TextStyle(
                                color: relation == choice.$1
                                    ? const Color(0xFF111111)
                                    : null,
                              ),
                            ),
                            selected: relation == choice.$1,
                            onSelected: (_) =>
                                setLocal(() => relation = choice.$1),
                          ),
                      ],
                    ),
                    if (errorText.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText,
                        style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () {
                    final phone = phoneController.text.trim();
                    final name = nameController.text.trim();
                    if (phone.length < 12) {
                      setLocal(() => errorText = 'Введите телефон');
                      return;
                    }
                    if (name.isEmpty) {
                      setLocal(() => errorText = 'Введите имя');
                      return;
                    }
                    Navigator.of(ctx).pop((
                      phone: phone,
                      name: name,
                      relation: relation,
                    ));
                  },
                  child: const Text('Добавить'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    final relationLabels = {
      'partner': 'Супруг',
      'child': 'Ребёнок',
      'parent': 'Родитель',
      'relative': 'Родственник',
      'other': 'Другой',
    };

    try {
      await ref.read(projectsRepositoryProvider).inviteMember(
            projectId: projectId,
            phone: result.phone,
            name: result.name,
            relation: relationLabels[result.relation] ?? result.relation,
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

class _DashedAddMemberButton extends StatelessWidget {
  const _DashedAddMemberButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.buttonRadius,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: colors.border,
            radius: AppRadius.button,
          ),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 22, color: colors.textPrimary),
                const SizedBox(width: 8),
                Text(
                  'Добавить участника',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 6.0;
      const gap = 4.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
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
              'Анкета заблокирована — этап планировки завершён',
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
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.divider),
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
                    color: colors.textSecondary,
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
        ],
      ),
    );
  }
}
