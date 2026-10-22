import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';

/// Shop tiles (top-level categories with subcategories).
final shopCategoriesProvider = FutureProvider<List<CatalogCategory>>((ref) {
  return ref.watch(catalogRepositoryProvider).getCategories();
});

/// List (default) or two-per-row grid; remembered between launches.
final shopGridViewProvider = NotifierProvider<ShopGridView, bool>(ShopGridView.new);

class ShopGridView extends Notifier<bool> {
  static const _key = 'shop_grid_view';

  @override
  bool build() {
    SharedPreferences.getInstance().then((p) {
      final saved = p.getBool(_key);
      if (saved != null && saved != state) state = saved;
    });
    return false;
  }

  void set(bool grid) {
    state = grid;
    SharedPreferences.getInstance().then((p) => p.setBool(_key, grid));
  }
}

class CategoryViewState {
  const CategoryViewState({
    this.subcategoryId,
    this.sort = ProductSort.popular,
    this.filters = CatalogFilters.empty,
    this.products = const [],
    this.total = 0,
    this.page = 1,
    this.totalPages = 1,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error = false,
  });

  final String? subcategoryId;
  final ProductSort sort;
  final CatalogFilters filters;
  final List<ProductSummary> products;
  final int total;
  final int page;
  final int totalPages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool error;

  CategoryViewState copyWith({
    String? subcategoryId,
    bool clearSubcategory = false,
    ProductSort? sort,
    CatalogFilters? filters,
    List<ProductSummary>? products,
    int? total,
    int? page,
    int? totalPages,
    bool? isLoading,
    bool? isLoadingMore,
    bool? error,
  }) {
    return CategoryViewState(
      subcategoryId: clearSubcategory ? null : (subcategoryId ?? this.subcategoryId),
      sort: sort ?? this.sort,
      filters: filters ?? this.filters,
      products: products ?? this.products,
      total: total ?? this.total,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error ?? this.error,
    );
  }
}

/// Products inside one shop tile. The key is the top category id ('' — whole catalog).
final categoryViewProvider =
    NotifierProvider.autoDispose.family<CategoryView, CategoryViewState, String>(CategoryView.new);

class CategoryView extends AutoDisposeFamilyNotifier<CategoryViewState, String> {
  int _generation = 0;

  @override
  CategoryViewState build(String topCategoryId) {
    Future<void>.microtask(reload);
    return const CategoryViewState();
  }

  CatalogRepository get _repo => ref.read(catalogRepositoryProvider);

  String? get _scopeId {
    final sub = state.subcategoryId;
    if (sub != null) return sub;
    return arg.isEmpty ? null : arg;
  }

  Future<void> reload() async {
    final gen = ++_generation;
    state = state.copyWith(isLoading: true, error: false);
    try {
      final page = await _repo.searchProducts(
        categoryId: _scopeId,
        filters: state.filters,
        sort: state.sort,
        page: 1,
      );
      if (gen != _generation) return;
      state = state.copyWith(
        products: page.items,
        total: page.total,
        page: 1,
        totalPages: page.totalPages,
        isLoading: false,
      );
    } catch (_) {
      if (gen != _generation) return;
      state = state.copyWith(isLoading: false, error: true);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || state.page >= state.totalPages) return;
    final gen = _generation;
    state = state.copyWith(isLoadingMore: true);
    try {
      final next = await _repo.searchProducts(
        categoryId: _scopeId,
        filters: state.filters,
        sort: state.sort,
        page: state.page + 1,
      );
      if (gen != _generation) return;
      state = state.copyWith(
        products: [...state.products, ...next.items],
        page: next.page,
        totalPages: next.totalPages,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void selectSubcategory(String? id) {
    state = id == null
        ? state.copyWith(clearSubcategory: true, filters: CatalogFilters.empty)
        : state.copyWith(subcategoryId: id, filters: CatalogFilters.empty);
    reload();
  }

  void setSort(ProductSort sort) {
    state = state.copyWith(sort: sort);
    reload();
  }

  void setFilters(CatalogFilters filters) {
    state = state.copyWith(filters: filters);
    reload();
  }

  /// Filter options for the current subcategory (or the whole tile).
  Future<FilterOptions> filterOptions() => _repo.getFilterOptions(categoryId: _scopeId);

  /// How many products a draft filter would show — for «Показать N товаров».
  Future<int> countFor(CatalogFilters filters) async {
    final page = await _repo.searchProducts(categoryId: _scopeId, filters: filters, sort: state.sort, page: 1, limit: 1);
    return page.total;
  }
}
