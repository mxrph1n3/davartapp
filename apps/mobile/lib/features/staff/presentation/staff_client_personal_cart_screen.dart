import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../catalog/presentation/widgets/shop_cart.dart';
import '../../commerce/data/commerce_models.dart';
import '../data/staff_repository.dart';

typedef _ClientPicks = ({Cart cart, List<FavoriteItem> favorites});

final _clientPicksProvider = FutureProvider.autoDispose.family<_ClientPicks, String>((ref, clientId) async {
  final repo = ref.watch(staffRepositoryProvider);
  final results = await Future.wait([repo.getClientPersonalCart(clientId), repo.getClientFavorites(clientId)]);
  return (cart: results[0] as Cart, favorites: results[1] as List<FavoriteItem>);
});

/// What the client put aside for themselves — personal cart and favourites, read-only.
/// The designer takes from here when assembling the подборка.
class StaffClientPersonalCartScreen extends ConsumerWidget {
  const StaffClientPersonalCartScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final async = ref.watch(_clientPicksProvider(clientId));
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppBackButton(fallback: AppRoutes.staffClientProfile(clientId)),
        title: const Text('Корзина и избранное'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить',
          onRetry: () => ref.invalidate(_clientPicksProvider(clientId)),
        ),
        data: (picks) {
          final items = picks.cart.items;
          if (items.isEmpty && picks.favorites.isEmpty) {
            return const EmptyState(icon: Icons.shopping_bag_outlined, title: 'Клиент пока ничего не отложил');
          }

          Widget title(String text) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
            child: Text(
              text,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
          );

          return RefreshIndicator(
            onRefresh: () => ref.refresh(_clientPicksProvider(clientId).future),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (items.isNotEmpty) ...[
                  title('Личная корзина · ${items.length}'),
                  for (final item in items)
                    _Row(
                      product: item.product,
                      detail: item.product.sellByPack
                          ? '${item.quantity} уп. · ${packAmountLabel(item.product.packSize, item.product.unit, item.quantity)}'
                          : packAmountLabel(null, item.product.unit, item.quantity),
                      price: formatPrice(item.subtotal),
                    ),
                ],
                if (picks.favorites.isNotEmpty) ...[
                  title('Избранное · ${picks.favorites.length}'),
                  for (final fav in picks.favorites)
                    _Row(
                      product: fav.product,
                      detail: '${formatPrice(fav.product.price)} / ${fav.product.unit}',
                      price: '',
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.product, required this.detail, required this.price});

  final CartProduct product;
  final String detail;
  final String price;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final placeholder = ColoredBox(color: colors.imagePlaceholder);
    return ListTile(
      onTap: () => context.push(AppRoutes.staffProductDetail(product.id)),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox.square(
          dimension: 52,
          child: (product.imageUrl ?? '').isEmpty
              ? placeholder
              : Image.network(product.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
        ),
      ),
      title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(detail),
      trailing: price.isEmpty ? null : Text(price, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
