import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';

class CatalogState {
  const CatalogState({
    this.categories = const [],
    this.products = const [],
    this.filterOptions,
    this.selectedCategoryId,
    this.searchQuery = '',
    this.filters = CatalogFilters.empty,
    this.sort = ProductSort.popular,
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.errorMessage,
  });

  final List<CatalogCategory> categories;
  final List<ProductSummary> products;
  final FilterOptions? filterOptions;
  final String? selectedCategoryId;
  final String searchQuery;
  final CatalogFilters filters;
  final ProductSort sort;
  final int page;
  final int totalPages;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isRefreshing;
  final String? errorMessage;

  bool get hasMore => page < totalPages;

  bool get isSearchMode =>
      searchQuery.isNotEmpty || filters.hasActiveFilters || sort != ProductSort.popular;

  CatalogState copyWith({
    List<CatalogCategory>? categories,
    List<ProductSummary>? products,
    FilterOptions? filterOptions,
    String? selectedCategoryId,
    bool clearCategory = false,
    String? searchQuery,
    CatalogFilters? filters,
    ProductSort? sort,
    int? page,
    int? totalPages,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isRefreshing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CatalogState(
      categories: categories ?? this.categories,
      products: products ?? this.products,
      filterOptions: filterOptions ?? this.filterOptions,
      selectedCategoryId: clearCategory
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      searchQuery: searchQuery ?? this.searchQuery,
      filters: filters ?? this.filters,
      sort: sort ?? this.sort,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final catalogProvider =
    NotifierProvider<CatalogNotifier, CatalogState>(CatalogNotifier.new);

class CatalogNotifier extends Notifier<CatalogState> {
  @override
  CatalogState build() => const CatalogState();

  CatalogRepository get _repository => ref.read(catalogRepositoryProvider);

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final results = await Future.wait([
        _repository.getCategories(),
        _repository.getFilterOptions(),
        _fetchProducts(page: 1),
      ]);

      final categories = results[0] as List<CatalogCategory>;
      final filterOptions = results[1] as FilterOptions;
      final productsPage = results[2] as ProductsPage;

      state = state.copyWith(
        categories: categories,
        filterOptions: filterOptions,
        products: productsPage.items,
        page: productsPage.page,
        totalPages: productsPage.totalPages,
        total: productsPage.total,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Не удалось загрузить каталог',
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      final productsPage = await _fetchProducts(page: 1);
      state = state.copyWith(
        products: productsPage.items,
        page: productsPage.page,
        totalPages: productsPage.totalPages,
        total: productsPage.total,
        isRefreshing: false,
      );
    } catch (_) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: 'Не удалось обновить каталог',
      );
    }
  }

  Future<void> selectCategory(String? categoryId) async {
    if (state.selectedCategoryId == categoryId) return;

    state = state.copyWith(
      selectedCategoryId: categoryId,
      clearCategory: categoryId == null,
      isLoading: true,
      clearError: true,
    );

    try {
      final productsPage = await _fetchProducts(page: 1);
      state = state.copyWith(
        products: productsPage.items,
        page: productsPage.page,
        totalPages: productsPage.totalPages,
        total: productsPage.total,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Не удалось загрузить товары',
      );
    }
  }

  Future<void> search(String query) async {
    state = state.copyWith(
      searchQuery: query.trim(),
      isLoading: true,
      clearError: true,
    );

    try {
      final productsPage = await _fetchProducts(page: 1);
      state = state.copyWith(
        products: productsPage.items,
        page: productsPage.page,
        totalPages: productsPage.totalPages,
        total: productsPage.total,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Не удалось выполнить поиск',
      );
    }
  }

  Future<void> applyFilters(CatalogFilters filters) async {
    state = state.copyWith(filters: filters, isLoading: true, clearError: true);

    try {
      final productsPage = await _fetchProducts(page: 1);
      state = state.copyWith(
        products: productsPage.items,
        page: productsPage.page,
        totalPages: productsPage.totalPages,
        total: productsPage.total,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Не удалось применить фильтры',
      );
    }
  }

  Future<void> clearFilters() async {
    await applyFilters(CatalogFilters.empty);
  }

  Future<void> removeFilter({
    bool minPrice = false,
    bool maxPrice = false,
    bool brandId = false,
    bool material = false,
    bool color = false,
    bool collection = false,
    bool inStock = false,
  }) async {
    final filters = state.filters.copyWith(
      clearMinPrice: minPrice,
      clearMaxPrice: maxPrice,
      clearBrandId: brandId,
      clearMaterial: material,
      clearColor: color,
      clearCollection: collection,
      clearInStock: inStock,
    );
    await applyFilters(filters);
  }

  Future<void> setSort(ProductSort sort) async {
    if (state.sort == sort) return;

    state = state.copyWith(sort: sort, isLoading: true, clearError: true);

    try {
      final productsPage = await _fetchProducts(page: 1);
      state = state.copyWith(
        products: productsPage.items,
        page: productsPage.page,
        totalPages: productsPage.totalPages,
        total: productsPage.total,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Не удалось отсортировать товары',
      );
    }
  }

  Future<void> clearSearch() async {
    state = state.copyWith(searchQuery: '', isLoading: true, clearError: true);

    try {
      final productsPage = await _fetchProducts(page: 1);
      state = state.copyWith(
        products: productsPage.items,
        page: productsPage.page,
        totalPages: productsPage.totalPages,
        total: productsPage.total,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Не удалось сбросить поиск',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.page + 1;
      final productsPage = await _fetchProducts(page: nextPage);

      state = state.copyWith(
        products: [...state.products, ...productsPage.items],
        page: productsPage.page,
        totalPages: productsPage.totalPages,
        total: productsPage.total,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: 'Не удалось загрузить ещё товары',
      );
    }
  }

  Future<ProductsPage> _fetchProducts({required int page}) {
    if (state.isSearchMode || state.searchQuery.isNotEmpty) {
      return _repository.searchProducts(
        query: state.searchQuery,
        categoryId: state.selectedCategoryId,
        filters: state.filters,
        sort: state.sort,
        page: page,
      );
    }

    if (state.filters.hasActiveFilters || state.sort != ProductSort.popular) {
      return _repository.searchProducts(
        categoryId: state.selectedCategoryId,
        filters: state.filters,
        sort: state.sort,
        page: page,
      );
    }

    return _repository.getProducts(
      categoryId: state.selectedCategoryId,
      page: page,
    );
  }
}

final productDetailProvider =
    FutureProvider.family<ProductDetail, String>((ref, productId) {
  return ref.watch(catalogRepositoryProvider).getProduct(productId);
});
