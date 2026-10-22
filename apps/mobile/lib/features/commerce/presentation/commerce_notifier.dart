import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_notifier.dart';
import '../../projects/data/projects_repository.dart';
import '../data/commerce_models.dart';
import '../data/commerce_repository.dart';

class CartState {
  const CartState({
    this.cart,
    this.projectCarts = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final Cart? cart;
  final List<Cart> projectCarts;
  final bool isLoading;
  final String? errorMessage;

  int get itemCount =>
      (cart?.itemCount ?? 0) +
      projectCarts.fold<int>(0, (sum, cart) => sum + cart.itemCount);

  bool get hasAnything =>
      (cart?.items.isNotEmpty ?? false) ||
      projectCarts.any((cart) => cart.items.isNotEmpty);

  CartState copyWith({
    Cart? cart,
    List<Cart>? projectCarts,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearCart = false,
  }) {
    return CartState(
      cart: clearCart ? null : (cart ?? this.cart),
      projectCarts: projectCarts ?? this.projectCarts,
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
    return const CartState();
  }

  CommerceRepository get _repository => ref.read(commerceRepositoryProvider);

  Future<void> loadCart() async {
    if (!ref.read(authProvider).isAuthenticated) {
      state = const CartState();
      return;
    }
    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final cart = await _repository.getCart();
      if (generation != _loadGeneration) return;
      var projectCarts = state.projectCarts;
      try {
        projectCarts = await _loadProjectCarts();
      } catch (_) {
        // Personal cart still shows if the project list is unavailable.
      }
      if (generation != _loadGeneration) return;
      state = state.copyWith(
        cart: cart,
        projectCarts: projectCarts,
        isLoading: false,
      );
    } catch (_) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Не удалось загрузить корзину',
      );
    }
  }

  /// Pull carts without a spinner and without cancelling a tap in progress.
  Future<void> refreshQuiet() async {
    if (!ref.read(authProvider).isAuthenticated) return;
    final generation = _loadGeneration;
    try {
      final cart = await _repository.getCart();
      if (generation != _loadGeneration) return;
      final projectCarts = await _loadProjectCarts();
      if (generation != _loadGeneration) return;
      state = state.copyWith(
        cart: cart,
        projectCarts: projectCarts,
        isLoading: false,
        clearError: true,
      );
    } catch (_) {}
  }

  Future<List<Cart>> _loadProjectCarts() async {
    final bundled = await _repository.getProjectCarts();
    if (bundled != null) return bundled;
    final projects = await ref.read(projectsRepositoryProvider).getProjects();
    final carts = <Cart>[];
    for (final project in projects) {
      if (project.isDraft || project.isShowcase) continue;
      try {
        final cart = await _repository.getCart(projectId: project.id);
        if (cart.items.isNotEmpty) carts.add(cart);
      } catch (_) {}
    }
    return carts;
  }

  Future<void> addProduct(String productId) async {
    final generation = ++_loadGeneration;
    try {
      final cart = await _repository.addToCart(productId: productId);
      if (generation != _loadGeneration) return;
      state = state.copyWith(cart: cart, clearError: true);
    } catch (_) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(errorMessage: 'Не удалось добавить в корзину');
      rethrow;
    }
  }

  Future<void> assignToProject(String projectId, List<CartItem> items) async {
    if (items.isEmpty) return;
    final generation = ++_loadGeneration;
    try {
      await _repository.assignToProject(
        projectId,
        items.map((item) => item.id).toList(),
      );
    } on DioException catch (error) {
      final body = '${error.response?.data}';
      final staleServer =
          error.response?.statusCode == 400 && body.contains('itemIds');
      if (!staleServer) rethrow;
      for (final item in items) {
        if (item.locked) continue;
        await _repository.addToCart(
          projectId: projectId,
          productId: item.product.id,
          quantity: item.quantity,
        );
        await _repository.removeCartItem(itemId: item.id);
      }
    }
    if (generation != _loadGeneration) return;
    await loadCart();
  }

  Future<void> updateQuantity(String itemId, int quantity) async {
    final generation = ++_loadGeneration;
    try {
      final cart = await _repository.updateCartItem(
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

  Future<void> updateProjectQuantity(
    String projectId,
    String itemId,
    int quantity,
  ) async {
    final generation = ++_loadGeneration;
    try {
      final cart = await _repository.updateCartItem(
        projectId: projectId,
        itemId: itemId,
        quantity: quantity,
      );
      if (generation != _loadGeneration) return;
      _replaceProjectCart(cart);
    } catch (_) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(errorMessage: 'Не удалось обновить количество');
    }
  }

  Future<void> removeProjectItem(String projectId, String itemId) async {
    final generation = ++_loadGeneration;
    try {
      final cart = await _repository.removeCartItem(
        projectId: projectId,
        itemId: itemId,
      );
      if (generation != _loadGeneration) return;
      _replaceProjectCart(cart);
    } catch (_) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(errorMessage: 'Не удалось удалить товар');
    }
  }

  void _replaceProjectCart(Cart cart) {
    final projectId = cart.projectId;
    final next = [
      for (final existing in state.projectCarts)
        if (existing.projectId != projectId) existing,
      if (cart.items.isNotEmpty) cart,
    ];
    state = state.copyWith(projectCarts: next, clearError: true);
  }

  Future<void> removeItem(String itemId) async {
    final generation = ++_loadGeneration;
    try {
      final cart = await _repository.removeCartItem(itemId: itemId);
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
