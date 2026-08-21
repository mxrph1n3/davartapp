import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'commerce_models.dart';

final commerceRepositoryProvider = Provider<CommerceRepository>((ref) {
  return CommerceRepository(ref.watch(dioProvider));
});

class CommerceRepository {
  CommerceRepository(this._dio);

  final Dio _dio;

  Future<Cart> getCart(String projectId) async {
    final response = await _dio.get(
      '/cart',
      queryParameters: {'projectId': projectId},
    );
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Cart> addToCart({
    required String projectId,
    required String productId,
    int quantity = 1,
  }) async {
    final response = await _dio.post(
      '/cart/items',
      data: {
        'projectId': projectId,
        'productId': productId,
        'quantity': quantity,
      },
    );
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Cart> updateCartItem({
    required String projectId,
    required String itemId,
    required int quantity,
  }) async {
    final response = await _dio.patch(
      '/cart/items/$itemId',
      queryParameters: {'projectId': projectId},
      data: {'quantity': quantity},
    );
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Cart> removeCartItem({
    required String projectId,
    required String itemId,
  }) async {
    final response = await _dio.delete(
      '/cart/items/$itemId',
      queryParameters: {'projectId': projectId},
    );
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Cart> clearCart(String projectId) async {
    final response = await _dio.delete(
      '/cart',
      queryParameters: {'projectId': projectId},
    );
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<FavoriteItem>> getFavorites() async {
    final response = await _dio.get('/favorites');
    return (response.data as List<dynamic>)
        .map((item) => FavoriteItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> addFavorite(String productId) async {
    await _dio.post('/favorites', data: {'productId': productId});
  }

  Future<void> removeFavorite(String productId) async {
    await _dio.delete('/favorites/$productId');
  }

  Future<Order> createOrder({
    required String projectId,
    required List<String> cartItemIds,
    required String address,
    String? comment,
  }) async {
    final response = await _dio.post(
      '/orders',
      data: {
        'projectId': projectId,
        'cartItemIds': cartItemIds,
        'address': address,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
    return Order.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Order>> getOrders() async {
    final response = await _dio.get('/orders');
    return (response.data as List<dynamic>)
        .map((item) => Order.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Order> getOrder(String orderId) async {
    final response = await _dio.get('/orders/$orderId');
    return Order.fromJson(response.data as Map<String, dynamic>);
  }
}
