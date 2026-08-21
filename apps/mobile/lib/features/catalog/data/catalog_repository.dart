import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'catalog_models.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(dioProvider));
});

class CatalogRepository {
  CatalogRepository(this._dio);

  final Dio _dio;

  Future<List<CatalogCategory>> getCategories() async {
    final response = await _dio.get('/catalog/categories');
    return (response.data as List<dynamic>)
        .map((item) => CatalogCategory.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<FilterOptions> getFilterOptions() async {
    final response = await _dio.get('/catalog/filters');
    return FilterOptions.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ProductsPage> getProducts({
    String? categoryId,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      '/catalog/products',
      queryParameters: <String, dynamic>{
        'page': page,
        'limit': limit,
        if (categoryId != null) 'categoryId': categoryId,
      },
    );

    return ProductsPage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ProductsPage> searchProducts({
    String? query,
    String? categoryId,
    CatalogFilters filters = CatalogFilters.empty,
    ProductSort sort = ProductSort.popular,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      '/catalog/search',
      queryParameters: <String, dynamic>{
        if (query != null && query.isNotEmpty) 'q': query,
        if (categoryId != null) 'categoryId': categoryId,
        if (filters.minPrice != null) 'minPrice': filters.minPrice,
        if (filters.maxPrice != null) 'maxPrice': filters.maxPrice,
        if (filters.brandId != null) 'brandId': filters.brandId,
        if (filters.material != null) 'material': filters.material,
        if (filters.color != null) 'color': filters.color,
        if (filters.collection != null) 'collection': filters.collection,
        if (filters.inStock != null) 'inStock': filters.inStock,
        'sort': sort.apiValue,
        'page': page,
        'limit': limit,
      },
    );

    return ProductsPage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ProductDetail> getProduct(String id) async {
    final response = await _dio.get('/catalog/products/$id');
    return ProductDetail.fromJson(response.data as Map<String, dynamic>);
  }
}
