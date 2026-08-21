import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../auth/presentation/require_login.dart';
import '../../staff/presentation/staff_cart_actions.dart';
import 'commerce_notifier.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration.zero, () {
      ref.read(favoritesProvider.notifier).loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppBackButton(
          fallback: catalogPathForRole(ref.watch(authProvider).user?.role),
        ),
        title: const Text('Избранное'),
      ),
      body: AuthGate(
        title: 'Войдите по номеру',
        subtitle: 'Избранное сохранится в вашем профиле',
        child: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.errorMessage != null && state.items.isEmpty
              ? ErrorState(
                  message: state.errorMessage!,
                  onRetry: () =>
                      ref.read(favoritesProvider.notifier).loadFavorites(),
                )
              : state.items.isEmpty
                  ? const EmptyState(
                      icon: Icons.favorite_border,
                      title: 'Нет избранных товаров',
                      subtitle: 'Добавляйте товары из каталога',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.screenPadding),
                      itemCount: state.items.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        color: AppColors.divider,
                      ),
                      itemBuilder: (context, index) {
                        final item = state.items[index];
                        return ProductCard(
                          name: item.product.name,
                          price: item.product.price,
                          imageUrl: item.product.imageUrl,
                          inStock: item.product.inStock,
                          isFavorite: true,
                          onTap: () => context.push(
                            AppRoutes.productDetail(item.product.id),
                          ),
                          onFavoriteToggle: () => ref
                              .read(favoritesProvider.notifier)
                              .toggleFavorite(item.product.id),
                          onAddToCart: () async {
                            try {
                              await addProductToActiveCart(
                                ref,
                                item.product.id,
                                context: context,
                              );
                            } catch (_) {}
                          },
                        );
                      },
                    ),
      ),
    );
  }
}
