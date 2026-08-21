import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_notifier.dart';
import '../data/commerce_models.dart';
import '../data/commerce_repository.dart';
import 'active_project_provider.dart';

class CartState {
  const CartState({
    this.cart,
    this.isLoading = false,
    this.errorMessage,
  });

  final Cart? cart;
  final bool isLoading;
  final String? errorMessage;

  int get itemCount => cart?.itemCount ?? 0;

  CartState copyWith({
    Cart? cart,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearCart = false,
  }) {
    return CartState(
      cart: clearCart ? null : (cart ?? this.cart),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);

class CartNotifier extends Notifier<CartState> {
  int _loadGeneration = 0;

  @override
  CartState build() {
    ref.listen(authProvider, (prev, next) {
      if (next.isAuthenticated && prev?.isAuthenticated != true) {
        loadCart();
      } else if (prev?.isAuthenticated == true && !next.isAuthenticated) {
        state = const CartState();
      }
    });
    ref.listen<ActiveProject?>(activeProjectProvider, (prev, next) {
      if (prev?.id != next?.id) {
        if (next == null) {
          state = const CartState();
        } else {
          loadCart();
        }
      }
    });
    return const CartState();
  }

  CommerceRepository get _repository => ref.read(commerceRepositoryProvider);

  String? get _projectId => ref.read(activeProjectProvider)?.id;

  Future<void> loadCart() async {
    if (!ref.read(authProvider).isAuthenticated) {
      state = const CartState();
      return;
    }
    final projectId = _projectId;
    final generation = ++_loadGeneration;
    if (projectId == null) {
      state = const CartState();
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final cart = await _repository.getCart(projectId);
      if (generation != _loadGeneration) return;
      state = state.copyWith(cart: cart, isLoading: false);
    } catch (_) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Не удалось загрузить корзину',
      );
    }
  }

  Future<void> addProduct(String productId) async {
    final projectId = _projectId;
    if (projectId == null) {
      state = state.copyWith(errorMessage: 'Выберите проект');
      throw StateError('No active project');
    }
    final generation = ++_loadGeneration;
    try {
      final cart = await _repository.addToCart(
        projectId: projectId,
        productId: productId,
      );
      if (generation != _loadGeneration) return;
      state = state.copyWith(cart: cart, clearError: true);
    } catch (_) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(errorMessage: 'Не удалось добавить в корзину');
      rethrow;
    }
  }

  Future<void> updateQuantity(String itemId, int quantity) async {
    final projectId = _projectId;
    if (projectId == null) return;
    final generation = ++_loadGeneration;
    try {
      final cart = await _repository.updateCartItem(
        projectId: projectId,
        itemId: itemId,
        quantity: quantity,
      );
      if (generation != _loadGeneration) return;
      state = state.copyWith(cart: cart, clearError: true);
    } catch (_) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(errorMessage: 'Не удалось обновить количество');
    }
  }

  Future<void> removeItem(String itemId) async {
    final projectId = _projectId;
    if (projectId == null) return;
    final generation = ++_loadGeneration;
    try {
      final cart = await _repository.removeCartItem(
        projectId: projectId,
        itemId: itemId,
      );
      if (generation != _loadGeneration) return;
      state = state.copyWith(cart: cart, clearError: true);
    } catch (_) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(errorMessage: 'Не удалось удалить товар');
    }
  }
}

class FavoritesState {
  const FavoritesState({
    this.items = const [],
    this.favoriteProductIds = const {},
    this.isLoading = false,
    this.errorMessage,
  });

  final List<FavoriteItem> items;
  final Set<String> favoriteProductIds;
  final bool isLoading;
  final String? errorMessage;

  bool isFavorite(String productId) => favoriteProductIds.contains(productId);

  FavoritesState copyWith({
    List<FavoriteItem>? items,
    Set<String>? favoriteProductIds,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FavoritesState(
      items: items ?? this.items,
      favoriteProductIds: favoriteProductIds ?? this.favoriteProductIds,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, FavoritesState>(FavoritesNotifier.new);

class FavoritesNotifier extends Notifier<FavoritesState> {
  @override
  FavoritesState build() {
    ref.listen(authProvider, (prev, next) {
      if (next.isAuthenticated && prev?.isAuthenticated != true) {
        loadFavorites();
      } else if (prev?.isAuthenticated == true && !next.isAuthenticated) {
        state = const FavoritesState();
      }
    });
    return const FavoritesState();
  }

  CommerceRepository get _repository => ref.read(commerceRepositoryProvider);

  Future<void> loadFavorites() async {
    if (!ref.read(authProvider).isAuthenticated) {
      state = const FavoritesState();
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _repository.getFavorites();
      state = state.copyWith(
        items: items,
        favoriteProductIds: items.map((item) => item.product.id).toSet(),
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Не удалось загрузить избранное',
      );
    }
  }

  Future<void> toggleFavorite(String productId) async {
    final isFavorite = state.isFavorite(productId);

    try {
      if (isFavorite) {
        await _repository.removeFavorite(productId);
        final updatedIds = Set<String>.from(state.favoriteProductIds)
          ..remove(productId);
        state = state.copyWith(
          favoriteProductIds: updatedIds,
          items: state.items
              .where((item) => item.product.id != productId)
              .toList(),
        );
      } else {
        await _repository.addFavorite(productId);
        final updatedIds = Set<String>.from(state.favoriteProductIds)
          ..add(productId);
        state = state.copyWith(favoriteProductIds: updatedIds);
        await loadFavorites();
      }
    } catch (_) {
      state = state.copyWith(errorMessage: 'Не удалось обновить избранное');
      rethrow;
    }
  }
}

final ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  if (!ref.watch(authProvider).isAuthenticated) return [];
  return ref.watch(commerceRepositoryProvider).getOrders();
});

final orderDetailProvider =
    FutureProvider.autoDispose.family<Order, String>((ref, orderId) {
  return ref.watch(commerceRepositoryProvider).getOrder(orderId);
});
