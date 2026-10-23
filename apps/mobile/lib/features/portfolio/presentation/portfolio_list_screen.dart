import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../data/portfolio_repository.dart';
import 'portfolio_widgets.dart';

typedef _ListKey = ({String? style, String? kind, PortfolioFilters filters});

final _portfolioListProvider = FutureProvider.autoDispose.family<List<PortfolioCard>, _ListKey>((ref, key) {
  return ref.watch(portfolioRepositoryProvider).list(style: key.style, kind: key.kind, filters: key.filters);
});

/// Large cards of one style (or kind); renders swipe inside the card; filter top right.
class PortfolioListScreen extends ConsumerStatefulWidget {
  const PortfolioListScreen({super.key, required this.title, this.style, this.kind});

  final String title;
  final String? style;
  final String? kind;

  @override
  ConsumerState<PortfolioListScreen> createState() => _PortfolioListScreenState();
}

class _PortfolioListScreenState extends ConsumerState<PortfolioListScreen> {
  var _filters = PortfolioFilters.empty;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final key = (style: widget.style, kind: widget.kind, filters: _filters);
    final list = ref.watch(_portfolioListProvider(key));
    final allProjects = widget.style == null && widget.kind == null;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppBackButton(fallback: AppRoutes.portfolio),
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Фильтр',
            onPressed: () => _openFilter(allProjects),
            icon: Badge(
              isLabelVisible: _filters.activeCount > 0,
              label: Text('${_filters.activeCount}'),
              backgroundColor: colors.accent,
              textColor: Colors.black,
              child: const Icon(Icons.tune),
            ),
          ),
        ],
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить проекты',
          onRetry: () => ref.invalidate(_portfolioListProvider(key)),
        ),
        data: (cards) {
          if (cards.isEmpty) {
            return EmptyState(
              icon: Icons.photo_library_outlined,
              title: 'Ничего не нашлось',
              subtitle: _filters.activeCount > 0 ? 'Попробуйте изменить фильтр' : null,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 32),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (_, i) {
              final c = cards[i];
              final parts = [
                c.title,
                if (c.area != null) portfolioArea(c.area!, kind: c.kind),
                if (allProjects) ?c.styleLabel,
              ];
              return ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: PortfolioCarousel(
                    images: c.images,
                    onTap: () => context.push(AppRoutes.portfolioProject(c.id)),
                    caption: Text(parts.join(' · '), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openFilter(bool withStyle) async {
    final next = await showModalBottomSheet<PortfolioFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(initial: _filters, withStyle: withStyle),
    );
    if (next != null) setState(() => _filters = next);
  }
}

const _areaRanges = <({String label, double? min, double? max})>[
  (label: 'до 50 м²', min: null, max: 50),
  (label: '50–80 м²', min: 50, max: 80),
  (label: '80–120 м²', min: 80, max: 120),
  (label: 'от 120 м²', min: 120, max: null),
];

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial, required this.withStyle});

  final PortfolioFilters initial;
  final bool withStyle;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late final _types = {...widget.initial.objectTypes};
  late var _area = _areaRanges.indexWhere((r) => r.min == widget.initial.areaMin && r.max == widget.initial.areaMax);
  late var _style = widget.initial.style;
  PortfolioFilterOptions? _options;

  @override
  void initState() {
    super.initState();
    ref
        .read(portfolioRepositoryProvider)
        .filterOptions()
        .then((o) {
          if (mounted) setState(() => _options = o);
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final title = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary);
    Widget chip(String label, bool on, VoidCallback onTap) => ChoiceChip(
      label: Text(label),
      selected: on,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: colors.accent,
      labelStyle: TextStyle(color: on ? Colors.black : colors.textPrimary),
    );
    final options = _options;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: options == null
            ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Тип объекта', style: title),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in options.objectTypes)
                        chip(
                          t,
                          _types.contains(t),
                          () => setState(() => _types.contains(t) ? _types.remove(t) : _types.add(t)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('Площадь', style: title),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _areaRanges.length; i++)
                        chip(_areaRanges[i].label, _area == i, () => setState(() => _area = _area == i ? -1 : i)),
                    ],
                  ),
                  if (widget.withStyle) ...[
                    const SizedBox(height: 18),
                    Text('Стиль', style: title),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in options.styles)
                          chip(
                            s.label,
                            _style == s.slug,
                            () => setState(() => _style = _style == s.slug ? null : s.slug),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, PortfolioFilters.empty),
                        child: Text('Сбросить', style: TextStyle(color: colors.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: colors.accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.pop(
                            context,
                            PortfolioFilters(
                              objectTypes: _types,
                              areaMin: _area < 0 ? null : _areaRanges[_area].min,
                              areaMax: _area < 0 ? null : _areaRanges[_area].max,
                              style: _style,
                            ),
                          ),
                          child: const Text('Показать', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
