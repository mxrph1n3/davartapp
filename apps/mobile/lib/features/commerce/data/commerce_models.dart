import '../../../core/utils/demo_media.dart';

class CartProduct {
  const CartProduct({
    required this.id,
    required this.name,
    required this.slug,
    required this.sku,
    required this.price,
    this.compareAtPrice,
    this.imageUrl,
    required this.inStock,
  });

  factory CartProduct.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return CartProduct(
      id: id,
      name: json['name'] as String,
      slug: json['slug'] as String,
      sku: json['sku'] as String,
      price: (json['price'] as num).toDouble(),
      compareAtPrice: (json['compareAtPrice'] as num?)?.toDouble(),
      imageUrl: demoProductImageUrl(
        productId: id,
        categorySlug: (json['category'] is Map
                ? (json['category'] as Map)['slug'] as String?
                : null) ??
            'mebel',
        imageUrl: json['imageUrl'] as String?,
      ),
      inStock: json['inStock'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final String slug;
  final String sku;
  final double price;
  final double? compareAtPrice;
  final String? imageUrl;
  final bool inStock;
}

class CartItem {
  const CartItem({
    required this.id,
    required this.quantity,
    required this.subtotal,
    required this.product,
    this.locked = false,
    this.lockedAt,
    this.lockedByOrderId,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String,
      quantity: json['quantity'] as int,
      subtotal: (json['subtotal'] as num).toDouble(),
      product: CartProduct.fromJson(json['product'] as Map<String, dynamic>),
      locked: json['locked'] as bool? ?? false,
      lockedAt: json['lockedAt'] != null
          ? DateTime.parse(json['lockedAt'] as String)
          : null,
      lockedByOrderId: json['lockedByOrderId'] as String?,
    );
  }

  final String id;
  final int quantity;
  final double subtotal;
  final CartProduct product;
  final bool locked;
  final DateTime? lockedAt;
  final String? lockedByOrderId;
}

class Cart {
  const Cart({
    required this.items,
    required this.total,
    required this.itemCount,
    this.projectId,
    this.projectName,
    this.ownerUserId,
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      items: (json['items'] as List<dynamic>)
          .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toDouble(),
      itemCount: json['itemCount'] as int,
      projectId: json['projectId'] as String?,
      projectName: json['projectName'] as String?,
      ownerUserId: json['ownerUserId'] as String?,
    );
  }

  final List<CartItem> items;
  final double total;
  final int itemCount;
  final String? projectId;
  final String? projectName;
  final String? ownerUserId;
}

class FavoriteItem {
  const FavoriteItem({required this.id, required this.product});

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      id: json['id'] as String,
      product: CartProduct.fromJson(json['product'] as Map<String, dynamic>),
    );
  }

  final String id;
  final CartProduct product;
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.price,
    required this.subtotal,
    required this.name,
    required this.sku,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      productId: json['productId'] as String,
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      name: json['name'] as String,
      sku: json['sku'] as String,
    );
  }

  final String id;
  final String productId;
  final int quantity;
  final double price;
  final double subtotal;
  final String name;
  final String sku;
}

class OrderStatusEntry {
  const OrderStatusEntry({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.createdAt,
  });

  factory OrderStatusEntry.fromJson(Map<String, dynamic> json) {
    return OrderStatusEntry(
      id: json['id'] as String,
      status: json['status'] as String,
      statusLabel: json['statusLabel'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String status;
  final String statusLabel;
  final DateTime createdAt;
}

class Order {
  const Order({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.address,
    this.comment,
    required this.totalAmount,
    required this.createdAt,
    required this.items,
    required this.statusHistory,
    this.userId,
    this.projectId,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      status: json['status'] as String,
      statusLabel: json['statusLabel'] as String,
      address: json['address'] as String,
      comment: json['comment'] as String?,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: (json['items'] as List<dynamic>)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      statusHistory: (json['statusHistory'] as List<dynamic>)
          .map((item) => OrderStatusEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
      userId: json['userId'] as String?,
      projectId: json['projectId'] as String?,
    );
  }

  final String id;
  final String status;
  final String statusLabel;
  final String address;
  final String? comment;
  final double totalAmount;
  final DateTime createdAt;
  final List<OrderItem> items;
  final List<OrderStatusEntry> statusHistory;
  final String? userId;
  final String? projectId;
}
