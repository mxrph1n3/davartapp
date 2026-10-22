import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../data/catalog_models.dart';
import 'shop_state.dart';
import 'widgets/shop_widgets.dart';

String _productsWord(int n) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return 'товар';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'товара';
  return 'товаров';
}

/// One shop tile: subcategory chips, «N товаров · сортировка», list/grid, filter.
class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(shopCategoriesProvider);
    final role = ref.watch(authProvider).user?.role;
    return categories.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(
          message: 'Не удалось загрузить каталог',
          onRetry: () => ref.invalidate(shopCategoriesProvider),
        ),
      ),
      data: (list) {
        if (slug == 'vse') {
          return _CategoryBody(topId: '', title: 'Весь каталог', chips: list, role: role);
        }
        final top = list.where((c) => c.slug == slug).firstOrNull;
        if (top == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.search_off, title: 'Раздел не найден'),
          );
        }
        return _CategoryBody(topId: top.id, title: top.name, chips: top.children, role: role);
      },
    );
  }
}

class _CategoryBody extends ConsumerStatefulWidget {
  const _CategoryBody({required this.topId, required this.title, required this.chips, required this.role});

  final String topId;
  final String title;
  final List<CatalogCategory> chips;
  final UserRole? role;

  @override
  ConsumerState<_CategoryBody> createState() => _CategoryBodyState();
}

class _CategoryBodyState extends ConsumerState<_CategoryBody> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) {
        ref.read(categoryViewProvider(widget.topId).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final view = ref.watch(categoryViewProvider(widget.topId));
    final notifier = ref.read(categoryViewProvider(widget.topId).notifier);
    final grid = ref.watch(shopGridViewProvider);
    final role = widget.role;
    void openProduct(ProductSummary p) => context.push(productPathForRole(role, p.id));

    final Widget products;
    if (view.isLoading) {
      products = const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
    } else if (view.error) {
      products = SliverFillRemaining(
        child: ErrorState(message: 'Не удалось загрузить товары', onRetry: notifier.reload),
      );
    } else if (view.products.isEmpty) {
      products = SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.inventory_2_outlined,
          title: view.filters.hasActiveFilters ? 'Ничего не нашлось' : 'Товары скоро появятся',
          subtitle: view.filters.hasActiveFilters ? 'Попробуйте изменить фильтры' : null,
        ),
      );
    } else if (grid) {
      products = SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 18,
            crossAxisSpacing: 12,
            mainAxisExtent: 318,
          ),
          itemCount: view.products.length,
          itemBuilder: (_, i) {
            final p = view.products[i];
            return ProductGridTile(product: p, onTap: () => openProduct(p));
          },
        ),
      );
    } else {
      products = SliverList.builder(
        itemCount: view.products.length,
        itemBuilder: (_, i) {
          final p = view.products[i];
          return ProductRow(product: p, onTap: () => openProduct(p));
        },
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: FittedBox(fit: BoxFit.scaleDown, child: Text(widget.title)),
        actions: [
          IconButton(
            tooltip: 'Поиск',
            onPressed: () => context.push(searchPathForRole(role)),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: notifier.reload,
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                if (widget.chips.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 46,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        children: [
                          _Chip(
                            label: 'Все',
                            selected: view.subcategoryId == null,
                            onTap: () => notifier.selectSubcategory(null),
                          ),
                          for (final c in widget.chips)
                            _Chip(
                              label: c.name,
                              selected: view.subcategoryId == c.id,
                              onTap: () => notifier.selectSubcategory(c.id),
                            ),
                        ],
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 6, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickSort(context, view.sort, notifier.setSort),
                            behavior: HitTestBehavior.opaque,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: '${view.total} ${_productsWord(view.total)} · '),
                                  TextSpan(
                                    text: view.sort.label.toLowerCase(),
                                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
                                  ),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Icon(Icons.expand_more, size: 18, color: colors.textPrimary),
                                  ),
                                ],
                              ),
                              style: TextStyle(fontSize: 13.5, color: colors.textSecondary),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: grid ? 'Списком' : 'Плиткой',
                          onPressed: () => ref.read(shopGridViewProvider.notifier).set(!grid),
                          icon: Icon(grid ? Icons.view_agenda_outlined : Icons.grid_view_outlined, size: 22),
                        ),
                      ],
                    ),
                  ),
                ),
                products,
                if (view.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                SliverToBoxAdapter(child: SizedBox(height: 96 + MediaQuery.paddingOf(context).bottom)),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
            child: Center(
              child: _FilterButton(
                count: view.filters.activeCount,
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: colors.background,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) => _FilterSheet(topId: widget.topId),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSort(BuildContext context, ProductSort current, ValueChanged<ProductSort> onPick) async {
    const options = [ProductSort.popular, ProductSort.priceAsc, ProductSort.priceDesc, ProductSort.newest];
    final picked = await showModalBottomSheet<ProductSort>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              ListTile(
                title: Text(o.label),
                trailing: o == current ? Icon(Icons.check, color: shopAccentLine(ctx)) : null,
                onTap: () => Navigator.pop(ctx, o),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && picked != current) onPick(picked);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? colors.textPrimary : colors.surfaceMuted,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: selected ? colors.background : colors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: colors.textPrimary,
      borderRadius: BorderRadius.circular(24),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune, size: 19, color: colors.background),
              const SizedBox(width: 8),
              Text(
                count > 0 ? 'Фильтры · $count' : 'Фильтры',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.background),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Price, characteristics, brand, «только в наличии»; «Показать N товаров» recounts live.
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.topId});

  final String topId;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late CatalogFilters _draft;
  FilterOptions? _options;
  int? _count;
  Timer? _debounce;
  late final TextEditingController _min;
  late final TextEditingController _max;
  final _expanded = <String>{};

  CategoryView get _notifier => ref.read(categoryViewProvider(widget.topId).notifier);

  @override
  void initState() {
    super.initState();
    _draft = ref.read(categoryViewProvider(widget.topId)).filters;
    _count = ref.read(categoryViewProvider(widget.topId)).total;
    _min = TextEditingController(text: _draft.minPrice?.round().toString() ?? '');
    _max = TextEditingController(text: _draft.maxPrice?.round().toString() ?? '');
    _notifier.filterOptions().then((o) {
      if (mounted) setState(() => _options = o);
    }).catchError((_) {
      if (mounted) {
        setState(() => _options = const FilterOptions(
              brands: [], materials: [], colors: [], collections: [], priceRange: PriceRange(min: 0, max: 0)));
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _update(CatalogFilters next) {
    setState(() => _draft = next);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final n = await _notifier.countFor(_draft);
        if (mounted) setState(() => _count = n);
      } catch (_) {}
    });
  }

  void _toggleAttr(String key, String value) {
    final attrs = {for (final e in _draft.attrs.entries) e.key: {...e.value}};
    final set = attrs.putIfAbsent(key, () => <String>{});
    if (!set.remove(value)) set.add(value);
    if (set.isEmpty) attrs.remove(key);
    _update(_draft.copyWith(attrs: attrs));
  }

  void _toggleBrand(String id) {
    final brands = {..._draft.brandIds};
    if (!brands.remove(id)) brands.add(id);
    _update(_draft.copyWith(brandIds: brands));
  }

  void _setPrice() {
    final min = double.tryParse(_min.text.replaceAll(' ', ''));
    final max = double.tryParse(_max.text.replaceAll(' ', ''));
    _update(_draft.copyWith(
      minPrice: min,
      maxPrice: max,
      clearMinPrice: min == null,
      clearMaxPrice: max == null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final options = _options;
    final titleStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary);

    Widget valueChip(String label, bool selected, VoidCallback onTap) {
      return FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        side: BorderSide(color: selected ? shopAccentLine(context) : colors.border, width: selected ? 1.5 : 1),
        selectedColor: colors.surfaceMuted,
        backgroundColor: colors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
    }

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
            child: Row(
              children: [
                Expanded(child: Text('Фильтры', style: titleStyle.copyWith(fontSize: 20))),
                if (_draft.hasActiveFilters)
                  TextButton(
                    onPressed: () {
                      _min.clear();
                      _max.clear();
                      _update(CatalogFilters.empty);
                    },
                    child: Text('Сбросить', style: TextStyle(color: colors.textSecondary)),
                  ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          Expanded(
            child: options == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    children: [
                      Text('Цена, ₽', style: titleStyle),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _PriceField(controller: _min, hint: 'от ${options.priceRange.min.round()}', onDone: _setPrice)),
                          const SizedBox(width: 10),
                          Expanded(child: _PriceField(controller: _max, hint: 'до ${options.priceRange.max.round()}', onDone: _setPrice)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Только в наличии'),
                        value: _draft.inStock == true,
                        activeTrackColor: shopAccentLine(context),
                        onChanged: (v) => _update(v ? _draft.copyWith(inStock: true) : _draft.copyWith(clearInStock: true)),
                      ),
                      for (final a in options.attributes) ...[
                        const SizedBox(height: 14),
                        Text(a.key, style: titleStyle),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final v in (_expanded.contains(a.key) ? a.values : a.values.take(8)))
                              valueChip(
                                v.value,
                                _draft.attrs[a.key]?.contains(v.value) == true,
                                () => _toggleAttr(a.key, v.value),
                              ),
                            if (a.values.length > 8 && !_expanded.contains(a.key))
                              ActionChip(
                                label: Text('Ещё ${a.values.length - 8}'),
                                onPressed: () => setState(() => _expanded.add(a.key)),
                              ),
                          ],
                        ),
                      ],
                      if (options.brands.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text('Бренд', style: titleStyle),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final b in options.brands)
                              valueChip(b.name, _draft.brandIds.contains(b.id), () => _toggleBrand(b.id)),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    _notifier.setFilters(_draft);
                    Navigator.pop(context);
                  },
                  child: Text(
                    _count == null ? 'Показать' : 'Показать $_count ${_productsWord(_count!)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({required this.controller, required this.hint, required this.onDone});

  final TextEditingController controller;
  final String hint;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => onDone(),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: colors.surfaceMuted,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
