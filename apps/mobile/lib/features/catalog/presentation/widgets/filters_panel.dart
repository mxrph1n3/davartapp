import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../data/catalog_models.dart';
import '../catalog_notifier.dart';

Future<CatalogFilters?> showFiltersPanel(BuildContext context) {
  return Navigator.of(context).push<CatalogFilters>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const FiltersPanel(),
    ),
  );
}

class FiltersPanel extends ConsumerStatefulWidget {
  const FiltersPanel({super.key});

  @override
  ConsumerState<FiltersPanel> createState() => _FiltersPanelState();
}

class _FiltersPanelState extends ConsumerState<FiltersPanel> {
  late double? _minPrice;
  late double? _maxPrice;
  String? _brandId;
  String? _material;
  String? _color;
  String? _collection;
  bool? _inStock;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(catalogProvider).filters;
    _minPrice = filters.minPrice;
    _maxPrice = filters.maxPrice;
    _brandId = filters.brandId;
    _material = filters.material;
    _color = filters.color;
    _collection = filters.collection;
    _inStock = filters.inStock;
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(catalogProvider).filterOptions;
    final count = ref.watch(catalogProvider).products.length;

    if (options == null) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Фильтры'),
          actions: [
            IconButton(
              tooltip: 'Закрыть',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close, size: 22),
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Фильтры',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 22),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                ),
                children: [
                  _section(
                    context,
                    title: 'Цена',
                    child: Column(
                      children: [
                        RangeSlider(
                          values: RangeValues(
                            _minPrice ?? options.priceRange.min,
                            (_maxPrice ?? options.priceRange.max).clamp(
                              options.priceRange.min,
                              options.priceRange.max <= options.priceRange.min
                                  ? options.priceRange.min + 1
                                  : options.priceRange.max,
                            ),
                          ),
                          min: options.priceRange.min,
                          max: options.priceRange.max <= options.priceRange.min
                              ? options.priceRange.min + 1
                              : options.priceRange.max,
                          divisions: 20,
                          activeColor: AppColors.accent,
                          inactiveColor: AppColors.divider,
                          onChanged: (v) => setState(() {
                            _minPrice = v.start;
                            _maxPrice = v.end;
                          }),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _priceBox(
                                '${(_minPrice ?? options.priceRange.min).round()} ₽',
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('—'),
                            ),
                            Expanded(
                              child: _priceBox(
                                '${(_maxPrice ?? options.priceRange.max).round()} ₽',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _selectRow(
                    context,
                    'Бренд',
                    _brandName(options),
                    () => _pickBrand(options),
                  ),
                  _selectRow(
                    context,
                    'Материал',
                    _material ?? 'Все',
                    () => _pickMaterial(options),
                  ),
                  if (options.collections.isNotEmpty)
                    _selectRow(
                      context,
                      'Коллекция',
                      _collectionName(options),
                      () => _pickCollection(options),
                    ),
                  _section(
                    context,
                    title: 'Цвет',
                    child: Wrap(
                      spacing: 10,
                      children: options.colors.take(6).map((color) {
                        final selected = _color == color;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _color = selected ? null : color),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surfaceMuted,
                              border: Border.all(
                                color: selected
                                    ? AppColors.textPrimary
                                    : AppColors.border,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              color.characters.first,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Только в наличии'),
                    value: _inStock ?? false,
                    activeThumbColor: AppColors.accent,
                    onChanged: (v) =>
                        setState(() => _inStock = v ? true : null),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                0,
                AppSpacing.screenPadding,
                AppSpacing.screenPadding,
              ),
              child: PrimaryButton(
                label: 'Показать ($count)',
                onPressed: () {
                  Navigator.of(context).pop(
                    CatalogFilters(
                      minPrice: _minPrice,
                      maxPrice: _maxPrice,
                      brandId: _brandId,
                      material: _material,
                      color: _color,
                      collection: _collection,
                      inStock: _inStock,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _brandName(FilterOptions options) {
    if (_brandId == null) return 'Все';
    return options.brands.firstWhere((b) => b.id == _brandId, orElse: () => const FilterBrand(id: '', name: 'Все', slug: '')).name;
  }

  Future<void> _pickBrand(FilterOptions options) async {
    final id = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => ListView(
        children: [
          ListTile(title: const Text('Все'), onTap: () => Navigator.pop(ctx, null)),
          ...options.brands.map(
            (b) => ListTile(title: Text(b.name), onTap: () => Navigator.pop(ctx, b.id)),
          ),
        ],
      ),
    );
    if (mounted) setState(() => _brandId = id);
  }

  String _collectionName(FilterOptions options) {
    if (_collection == null) return 'Все';
    return options.collections
        .firstWhere(
          (item) => item.slug == _collection,
          orElse: () => FilterCollection(slug: '', name: _collection!),
        )
        .name;
  }

  Future<void> _pickCollection(FilterOptions options) async {
    final slug = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => ListView(
        children: [
          ListTile(
            title: const Text('Все'),
            onTap: () => Navigator.pop(ctx, null),
          ),
          ...options.collections.map(
            (item) => ListTile(
              title: Text(item.name),
              onTap: () => Navigator.pop(ctx, item.slug),
            ),
          ),
        ],
      ),
    );
    if (mounted) setState(() => _collection = slug);
  }

  Future<void> _pickMaterial(FilterOptions options) async {
    final value = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => ListView(
        children: [
          ListTile(title: const Text('Все'), onTap: () => Navigator.pop(ctx, null)),
          ...options.materials.map(
            (m) => ListTile(title: Text(m), onTap: () => Navigator.pop(ctx, m)),
          ),
        ],
      ),
    );
    if (mounted) setState(() => _material = value);
  }

  Widget _section(BuildContext context, {required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }

  Widget _priceBox(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.inputRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(value),
    );
  }

  Widget _selectRow(BuildContext context, String title, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.bodyLarge)),
            Text(value, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
