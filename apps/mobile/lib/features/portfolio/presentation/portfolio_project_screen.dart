import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/top_notice.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../auth/presentation/require_login.dart';
import '../../projects/data/projects_repository.dart';
import '../../projects/presentation/projects_notifier.dart';
import '../data/portfolio_repository.dart';
import 'portfolio_widgets.dart';

final portfolioProjectProvider = FutureProvider.autoDispose.family<PortfolioProject, String>((ref, id) {
  return ref.watch(portfolioRepositoryProvider).project(id);
});

const _months = [
  'январь',
  'февраль',
  'март',
  'апрель',
  'май',
  'июнь',
  'июль',
  'август',
  'сентябрь',
  'октябрь',
  'ноябрь',
  'декабрь',
];

/// Project album: renders on top (tap → full screen), plaques 2×3, rooms, materials sum,
/// description; the number small and dim at the very bottom, like an article number.
class PortfolioProjectScreen extends ConsumerStatefulWidget {
  const PortfolioProjectScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<PortfolioProjectScreen> createState() => _PortfolioProjectScreenState();
}

class _PortfolioProjectScreenState extends ConsumerState<PortfolioProjectScreen> {
  bool? _favorite;
  var _ordering = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final async = ref.watch(portfolioProjectProvider(widget.id));
    final isStudio = ref.watch(authProvider).user?.role.isStudio == true;

    return async.when(
      loading: () => Scaffold(
        backgroundColor: colors.background,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(
          message: 'Не удалось загрузить проект',
          onRetry: () => ref.invalidate(portfolioProjectProvider(widget.id)),
        ),
      ),
      data: (p) {
        final favorite = _favorite ?? p.favorite;
        final plaques = <({IconData icon, String label, String value})>[
          (icon: Icons.design_services_outlined, label: 'Дизайн-проект', value: p.kindLabel),
          if (p.styleLabel != null) (icon: Icons.palette_outlined, label: 'Стиль', value: p.styleLabel!),
          if (p.area != null) (icon: Icons.square_foot, label: 'Площадь', value: portfolioArea(p.area!, kind: p.kind)),
          if (p.designer != null) (icon: Icons.person_outline, label: 'Дизайнер', value: p.designer!),
          if (p.completedAt != null)
            (
              icon: Icons.event_available_outlined,
              label: 'Проект сдан',
              value: '${_months[p.completedAt!.month - 1]} ${p.completedAt!.year}',
            ),
          if (p.rooms.isNotEmpty) (icon: Icons.meeting_room_outlined, label: 'Помещения', value: '${p.rooms.length}'),
        ];

        return Scaffold(
          backgroundColor: colors.background,
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _Gallery(images: p.images)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    sliver: SliverList.list(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.title,
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: colors.textPrimary),
                              ),
                            ),
                            if (p.inRealization)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: colors.accent),
                                ),
                                child: Text('В реализации', style: TextStyle(fontSize: 12, color: colors.textPrimary)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        GridView.count(
                          padding: EdgeInsets.zero,
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 2.6,
                          children: [for (final q in plaques) _Plaque(icon: q.icon, label: q.label, value: q.value)],
                        ),
                        if (p.rooms.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final r in p.rooms)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(r, style: TextStyle(fontSize: 12.5, color: colors.textPrimary)),
                                ),
                            ],
                          ),
                        ],
                        if (p.materialsCost != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.surfaceMuted,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: colors.accent, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.chair_outlined, color: colors.accent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Материалы и мебель в проекте',
                                    style: TextStyle(fontSize: 14, color: colors.textPrimary),
                                  ),
                                ),
                                Text(
                                  formatPrice(p.materialsCost!),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if ((p.description ?? '').isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Text(
                            p.description!,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.45,
                              color: colors.textPrimary.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (p.related.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      sliver: SliverList.list(
                        children: [
                          Text(
                            'Этот объект в других проектах',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: colors.textPrimary),
                          ),
                          const SizedBox(height: 7),
                          for (final r in p.related) _RelatedRow(item: r),
                        ],
                      ),
                    ),
                  // Pushes the number just below the bottom edge: it is seen only after scrolling down.
                  const SliverFillRemaining(hasScrollBody: false, child: SizedBox.shrink()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
                      child: Center(
                        child: Text(
                          'Проект № ${p.number}',
                          style: TextStyle(fontSize: 11.5, color: colors.textSecondary.withValues(alpha: 0.6)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Back and share stay in place while the page scrolls.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: Row(
                      children: [
                        _RoundButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => popOrGo(context, AppRoutes.portfolio),
                        ),
                        const Spacer(),
                        _RoundButton(icon: Icons.ios_share_rounded, onTap: () => _share(p)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: isStudio
              ? null
              : SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => _toggleFavorite(p.id, !favorite),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: favorite ? colors.accent : null,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: favorite ? colors.accent : colors.border, width: 1.5),
                            ),
                            child: Icon(
                              favorite ? Icons.favorite : Icons.favorite_border,
                              color: favorite ? Colors.black : colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _ordering ? null : _order,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              backgroundColor: colors.accent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text(
                              'Заказать проект',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Future<void> _toggleFavorite(String id, bool on) async {
    if (!await promptLogin(context, ref)) return;
    setState(() => _favorite = on);
    try {
      await ref.read(portfolioRepositoryProvider).setFavorite(id, on);
    } catch (_) {
      if (!mounted) return;
      setState(() => _favorite = !on);
      showTopNotice(context, 'Не удалось обновить избранное');
    }
  }

  /// Same as «Заказать проект» on the Design tab: a new questionnaire.
  Future<void> _order() async {
    if (!await promptLogin(context, ref)) return;
    if (!mounted) return;
    setState(() => _ordering = true);
    try {
      final project = await ref.read(projectsRepositoryProvider).createProject();
      ref.invalidate(projectsListProvider);
      if (mounted) context.push(AppRoutes.projectBrief(project.id));
    } catch (_) {
      if (mounted) showTopNotice(context, 'Не удалось создать проект');
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  Future<void> _share(PortfolioProject p) async {
    final parts = [
      p.title,
      if (p.styleLabel != null) p.styleLabel!,
      if (p.area != null) portfolioArea(p.area!, kind: p.kind),
    ];
    await Clipboard.setData(ClipboardData(text: '${parts.join(' · ')} — проект DAVart'));
    if (mounted) showTopNotice(context, 'Скопировано');
  }
}

/// Renders in their original proportions: the block takes the height of the current image.
class _Gallery extends StatefulWidget {
  const _Gallery({required this.images});

  final List<PortfolioImage> images;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final urls = [for (final i in images) i.url];
    final width = MediaQuery.sizeOf(context).width;
    final aspect = images.isEmpty ? 4 / 3 : images[_index].aspect;
    // Very tall renders would push everything below the fold.
    final height = (width / aspect).clamp(width * 0.5, width * 1.35);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => PortfolioViewer.open(context, urls, i),
              child: PortfolioImageView(urls[i]),
            ),
          ),
          if (images.length > 1)
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '${_index + 1} / ${images.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Plaque extends StatelessWidget {
  const _Plaque({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: colors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 22, color: colors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small plaque: thumbnail, title, kind · style · area, chevron; opens that project.
class _RelatedRow extends StatelessWidget {
  const _RelatedRow({required this.item});

  final PortfolioRelated item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = Theme.of(context).brightness == Brightness.dark ? colors.accent : const Color(0xFFD9B800);
    // The plaque names the kind of project; the object and figures go underneath.
    final title = switch (item.kind) {
      'exterior' => 'Дизайн-проект экстерьера',
      'architecture' => 'Архитектурный проект',
      'landscape' => 'Ландшафтный дизайн-проект',
      _ => 'Дизайн-проект интерьера',
    };
    final subtitle = [
      item.title,
      ?item.styleLabel,
      if (item.area != null) portfolioArea(item.area!, kind: item.kind),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          // A light but crisp outline: thin line plus a tight glow that hugs it.
          boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.28), blurRadius: 3, spreadRadius: 0.2)],
        ),
        child: Material(
          color: colors.surfaceMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
            side: BorderSide(color: accent.withValues(alpha: 0.7), width: 0.8),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(AppRoutes.portfolioProject(item.id)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 5, 8, 5),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: SizedBox(width: 54, height: 38, child: PortfolioImageView(item.coverUrl)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: colors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: colors.background.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(dimension: 42, child: Icon(icon, size: 18, color: colors.textPrimary)),
      ),
    );
  }
}
