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

final _personalCartProvider = FutureProvider.autoDispose.family<Cart, String>((ref, clientId) {
  return ref.watch(staffRepositoryProvider).getClientPersonalCart(clientId);
});

/// The client's own cart, read-only: the designer looks here when assembling the подборка.
class StaffClientPersonalCartScreen extends ConsumerWidget {
  const StaffClientPersonalCartScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final async = ref.watch(_personalCartProvider(clientId));
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppBackButton(fallback: AppRoutes.staffClientProfile(clientId)),
        title: const Text('Личная корзина клиента'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить корзину',
          onRetry: () => ref.invalidate(_personalCartProvider(clientId)),
        ),
        data: (cart) {
          if (cart.items.isEmpty) {
            return const EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Клиент пока ничего не отложил',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(_personalCartProvider(clientId).future),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: cart.items.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: colors.divider),
              itemBuilder: (_, i) {
                final item = cart.items[i];
                final p = item.product;
                final qty = p.sellByPack
                    ? '${item.quantity} уп. · ${packAmountLabel(p.packSize, p.unit, item.quantity)}'
                    : packAmountLabel(null, p.unit, item.quantity);
                return ListTile(
                  onTap: () => context.push(AppRoutes.staffProductDetail(p.id)),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox.square(
                      dimension: 52,
                      child: (p.imageUrl ?? '').isEmpty
                          ? ColoredBox(color: colors.imagePlaceholder)
                          : Image.network(
                              p.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => ColoredBox(color: colors.imagePlaceholder),
                            ),
                    ),
                  ),
                  title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(qty),
                  trailing: Text(
                    formatPrice(item.subtotal),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
