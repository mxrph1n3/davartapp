import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';

/// Isolated search results — does not mutate [catalogProvider].
class SearchState {
  const SearchState({
    this.query = '',
    this.products = const [],
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final String query;
  final List<ProductSummary> products;
  final int page;
  final int totalPages;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  bool get hasMore => page < totalPages;

  SearchState copyWith({
    String? query,
    List<ProductSummary>? products,
    int? page,
    int? totalPages,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      products: products ?? this.products,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final searchProvider =
    NotifierProvider.autoDispose<SearchNotifier, SearchState>(SearchNotifier.new);

class SearchNotifier extends AutoDisposeNotifier<SearchState> {
  @override
  SearchState build() => const SearchState();

  CatalogRepository get _repository => ref.read(catalogRepositoryProvider);

  Future<void> search(String query) async {
    final trimmed = query.trim();
    state = state.copyWith(
      query: trimmed,
      isLoading: true,
      clearError: true,
    );

    if (trimmed.isEmpty) {
      state = state.copyWith(
        products: const [],
        page: 1,
        totalPages: 1,
        total: 0,
        isLoading: false,
      );
      return;
    }

    try {
      final page = await _repository.searchProducts(
        query: trimmed,
        page: 1,
      );
      state = state.copyWith(
        products: page.items,
        page: page.page,
        totalPages: page.totalPages,
        total: page.total,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Не удалось выполнить поиск',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.query.isEmpty) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.page + 1;
      final page = await _repository.searchProducts(
        query: state.query,
        page: nextPage,
      );
      state = state.copyWith(
        products: [...state.products, ...page.items],
        page: page.page,
        totalPages: page.totalPages,
        total: page.total,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: 'Не удалось загрузить ещё товары',
      );
    }
  }
}
