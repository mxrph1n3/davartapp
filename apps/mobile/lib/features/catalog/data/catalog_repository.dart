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

  Future<FilterOptions> getFilterOptions({String? categoryId}) async {
    final response = await _dio.get(
      '/catalog/filters',
      queryParameters: {'categoryId': ?categoryId},
    );
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
        'categoryId': ?categoryId,
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
      options: Options(listFormat: ListFormat.multi),
      queryParameters: <String, dynamic>{
        if (query != null && query.isNotEmpty) 'q': query,
        'categoryId': ?categoryId,
        if (filters.minPrice != null) 'minPrice': filters.minPrice,
        if (filters.maxPrice != null) 'maxPrice': filters.maxPrice,
        if (filters.brandId != null) 'brandId': filters.brandId,
        if (filters.material != null) 'material': filters.material,
        if (filters.color != null) 'color': filters.color,
        if (filters.collection != null) 'collection': filters.collection,
        if (filters.inStock != null) 'inStock': filters.inStock,
        if (filters.brandIds.isNotEmpty) 'brandIds': filters.brandIds.join(','),
        if (filters.attrs.values.any((v) => v.isNotEmpty))
          'attr': [
            for (final e in filters.attrs.entries)
              for (final v in e.value) '${e.key}:$v',
          ],
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
