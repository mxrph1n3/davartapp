import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../data/projects_models.dart';
import '../data/project_summary.dart';
import 'projects_notifier.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  String? _objectType;
  String? _rooms;
  String? _area;
  String? _style;

  static const _objectTypes = [
    'Квартира',
    'Дом',
    'Офис',
    'Коммерческое помещение',
  ];
  static const _roomOptions = ['1', '2', '3', '4+'];
  static const _areaOptions = [
    ('upto50', 'До 50 м²'),
    ('50_100', '50–100 м²'),
    ('100_200', '100–200 м²'),
    ('from200', 'От 200 м²'),
  ];

  bool _matchesArea(double? area, String? filter) {
    if (filter == null || area == null) return filter == null;
    switch (filter) {
      case 'upto50':
        return area < 50;
      case '50_100':
        return area >= 50 && area < 100;
      case '100_200':
        return area >= 100 && area < 200;
      case 'from200':
        return area >= 200;
      default:
        return true;
    }
  }

  int _roomCount(Project project) => projectRoomCount(project) ?? 0;

  bool _matchesRooms(Project project, String? filter) {
    if (filter == null) return true;
    final count = _roomCount(project);
    if (count == 0) return false;
    if (filter == '4+') return count >= 4;
    return count == int.tryParse(filter);
  }

  List<Project> _filter(List<Project> items) {
    return items.where((project) {
      if (_objectType != null && project.objectType != _objectType) {
        return false;
      }
      if (_objectType == 'Квартира' && !_matchesRooms(project, _rooms)) {
        return false;
      }
      if (!_matchesArea(project.area, _area)) return false;
      if (_style != null) {
        final style = project.style?.trim() ?? '';
        if (style != _style) return false;
      }
      return true;
    }).toList();
  }

  void _toggle(String? current, String value, void Function(String?) set) {
    set(current == value ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    final showcaseAsync = ref.watch(showcaseProjectsProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppBackButton(fallback: AppRoutes.projects),
        title: const Text('Портфолио'),
      ),
      body: showcaseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить портфолио',
          onRetry: () => ref.invalidate(showcaseProjectsProvider),
        ),
        data: (items) {
          final styles = items
              .map((p) => p.style?.trim())
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          final filtered = _filter(items);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(showcaseProjectsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                Text(
                  'Тип объекта',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                _ChipRow(
                  labels: _objectTypes,
                  selected: _objectType,
                  onTap: (value) => setState(() {
                    _toggle(_objectType, value, (v) {
                      _objectType = v;
                      if (v != 'Квартира') _rooms = null;
                    });
                  }),
                ),
                if (_objectType == 'Квартира') ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Количество комнат',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ChipRow(
                    labels: _roomOptions,
                    selected: _rooms,
                    onTap: (value) => setState(
                      () => _toggle(_rooms, value, (v) => _rooms = v),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Площадь',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                _ChipRow(
                  labels: [for (final item in _areaOptions) item.$2],
                  selected: _area == null
                      ? null
                      : _areaOptions
                          .firstWhere((item) => item.$1 == _area)
                          .$2,
                  onTap: (label) {
                    final id = _areaOptions
                        .firstWhere((item) => item.$2 == label)
                        .$1;
                    setState(() => _toggle(_area, id, (v) => _area = v));
                  },
                ),
                if (styles.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Стиль',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ChipRow(
                    labels: styles,
                    selected: _style,
                    onTap: (value) => setState(
                      () => _toggle(_style, value, (v) => _style = v),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'Нет проектов по выбранным фильтрам',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.of(context).textSecondary,
                          ),
                    ),
                  )
                else
                  ...filtered.map(
                    (project) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: ProjectCard(
                        name: project.name,
                        status: project.status,
                        statusLabel: [
                          if (project.objectType != null) project.objectType!,
                          if (project.area != null)
                            '${project.area!.round()} м²',
                          if (project.style != null) project.style!,
                          if (project.objectType == 'Квартира' &&
                              _roomCount(project) > 0)
                            '${_roomCount(project)} комн.',
                        ].join(' · '),
                        address: project.address,
                        coverUrl: projectCoverUrl(project.id),
                        onTap: () => context.push(
                          AppRoutes.projectDetail(project.id),
                        ),
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

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.labels,
    required this.selected,
    required this.onTap,
  });

  final List<String> labels;
  final String? selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          Material(
            color: selected == label
                ? colors.accent
                : colors.surfaceMuted,
            borderRadius: AppRadius.pillRadius,
            child: InkWell(
              onTap: () => onTap(label),
              borderRadius: AppRadius.pillRadius,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.pillRadius,
                  border: Border.all(
                    color: selected == label
                        ? colors.accent
                        : colors.border,
                  ),
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
