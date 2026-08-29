import 'package:flutter/cupertino.dart';
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
import '../../commerce/presentation/active_project_provider.dart';
import '../data/projects_models.dart';
import '../data/projects_repository.dart';
import '../data/project_summary.dart';
import 'projects_notifier.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  bool _creating = false;

  Future<void> _createProject() async {
    if (_creating) return;
    if (!await promptLogin(context, ref)) return;
    if (!mounted) return;

    setState(() => _creating = true);
    try {
      final project =
          await ref.read(projectsRepositoryProvider).createProject();
      ref.invalidate(projectsListProvider);
      if (!mounted) return;
      context.push(AppRoutes.projectBrief(project.id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось создать проект')),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _showProjectActions(Project project) async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(project.name),
        message: const Text('Проект на этапе «Бриф» можно удалить'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, 'delete'),
            child: const Text('Удалить проект'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (action != 'delete' || !mounted) return;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Удалить проект?'),
        content: Text('«${project.name}» будет удалён безвозвратно.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _deleteProject(project);
  }

  Future<void> _deleteProject(Project project) async {
    try {
      await ref.read(projectsRepositoryProvider).deleteProject(project.id);
      final active = ref.read(activeProjectProvider);
      if (active?.id == project.id) {
        ref.read(activeProjectProvider.notifier).state = null;
      }
      ref.invalidate(projectsListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Проект удалён')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить проект')),
      );
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
          final ordered = [...projects]
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          final noOwnProjects = ordered.isEmpty;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(projectsListProvider);
              ref.invalidate(showcaseProjectsProvider);
            },
            child: ListView(
              clipBehavior: Clip.none,
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                const ScreenHeader(title: 'Проекты'),
                if (!ref.watch(authProvider).isAuthenticated && noOwnProjects)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: EmptyState(
                      icon: Icons.folder_open_outlined,
                      title: 'Ваши проекты появятся здесь',
                      subtitle:
                          'Войдите по номеру, чтобы создать проект или увидеть свои',
                      actionLabel: 'Войти',
                      onAction: () => promptLogin(context, ref),
                    ),
                  )
                else ...[
                  ...ordered.map(
                    (project) => ProjectCard(
                      compact: true,
                      name: project.name,
                      status: project.status,
                      statusLabel: project.statusLabel,
                      address: projectBriefSummary(project) ??
                          project.objectType ??
                          project.address,
                      coverUrl: projectCoverUrl(project.id),
                      onTap: () =>
                          context.push(AppRoutes.projectDetail(project.id)),
                      onMorePressed: project.status == 'brief_filling'
                          ? () => _showProjectActions(project)
                          : null,
                    ),
                  ),
                  _OrderProjectButton(
                    isLoading: _creating,
                    onPressed: _creating ? null : _createProject,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                _PortfolioEntryCard(
                  coverUrl: showcaseAsync.asData?.value.isNotEmpty == true
                      ? projectCoverUrl(showcaseAsync.asData!.value.first.id)
                      : null,
                  onTap: () => context.push(AppRoutes.portfolio),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PortfolioEntryCard extends StatelessWidget {
  const _PortfolioEntryCard({
    required this.onTap,
    this.coverUrl,
  });

  final VoidCallback onTap;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: colors.imagePlaceholder,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (coverUrl != null)
                  Image.network(
                    coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: colors.imagePlaceholder,
                    ),
                  )
                else
                  ColoredBox(color: colors.imagePlaceholder),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Портфолио работ',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Смотреть проекты студии',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                      ),
                    ],
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

class _OrderProjectButton extends StatelessWidget {
  const _OrderProjectButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final enabled = onPressed != null && !isLoading;
    final color = enabled ? colors.textPrimary : colors.textDisabled;
    // Contour extends equally past list padding; content stays aligned
    // with compact ProjectCard (+ under thumbs, title under titles).
    const gap = 12.0;
    const radius = 24.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -gap,
            right: -gap,
            top: 0,
            bottom: 0,
            child: CustomPaint(
              painter: _DashedRRectPainter(
                color: enabled
                    ? colors.textPrimary.withValues(alpha: 0.4)
                    : colors.border,
                radius: radius,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: gap),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: ColoredBox(
                      color: colors.surfaceMuted,
                      child: isLoading
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.add,
                              size: 32,
                              color: color,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Новый проект',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                          color: color,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            left: -gap,
            right: -gap,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled ? onPressed : null,
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final inset = paint.strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - paint.strokeWidth, size.height - paint.strokeWidth),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
