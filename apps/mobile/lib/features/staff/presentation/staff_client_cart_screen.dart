import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../catalog/presentation/widgets/shop_cart.dart';
import '../../commerce/presentation/active_project_provider.dart';
import '../../commerce/presentation/cart_selection_provider.dart';
import '../data/staff_repository.dart';
import 'staff_cart_actions.dart';
import 'working_client_provider.dart';

class StaffProjectCartScreen extends ConsumerStatefulWidget {
  const StaffProjectCartScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<StaffProjectCartScreen> createState() =>
      _StaffProjectCartScreenState();
}

class _StaffProjectCartScreenState
    extends ConsumerState<StaffProjectCartScreen> {
  void _syncSelection(List<String> unlockedIds) {
    final scope = 'staff:${widget.projectId}';
    final unlocked = unlockedIds.toSet();
    final current = ref.read(cartSelectionProvider(scope));
    final next = current.intersection(unlocked);
    if (next.isEmpty && unlocked.isNotEmpty) {
      ref.read(cartSelectionProvider(scope).notifier).state = unlocked;
    } else if (next.length != current.length) {
      ref.read(cartSelectionProvider(scope).notifier).state = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectId = widget.projectId;
    final cartAsync = ref.watch(staffProjectCartProvider(projectId));
    final project = ref.watch(activeProjectProvider);
    final working = ref.watch(workingClientProvider);
    final selection = ref.watch(cartSelectionProvider('staff:$projectId'));
    final title = project?.id == projectId
        ? 'Корзина · ${project!.name}'
        : (working != null
            ? 'Корзина · ${working.displayName}'
            : 'Корзина проекта');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => popOrGo(context, AppRoutes.staffClients),
        ),
        actions: [
          IconButton(
            tooltip: 'В каталог',
            icon: const Icon(Icons.grid_view_outlined),
            onPressed: () => context.go(AppRoutes.staffCatalog),
          ),
        ],
      ),
      body: cartAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить корзину',
          onRetry: () => ref.invalidate(staffProjectCartProvider(projectId)),
        ),
        data: (cart) {
          final unlocked = cart.items.where((i) => !i.locked).toList();
          if (unlocked.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Корзина пуста',
              subtitle: 'Добавьте товары из каталога для этого проекта',
              actionLabel: 'В каталог',
              onAction: () => context.go(AppRoutes.staffCatalog),
            );
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _syncSelection(unlocked.map((i) => i.id).toList());
            }
          });

          final selectedItems =
              unlocked.where((i) => selection.contains(i.id)).toList();
          final selectedTotal =
              selectedItems.fold<double>(0, (sum, i) => sum + i.subtotal);

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  itemCount: unlocked.length,
                  separatorBuilder: (_, _) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final item = unlocked[index];
                    final selected = selection.contains(item.id);
                    return Opacity(
                      opacity: item.locked ? 0.55 : 1,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: item.locked ? false : selected,
                            onChanged: item.locked
                                ? null
                                : (value) {
                                    final next = Set<String>.from(selection);
                                    if (value == true) {
                                      next.add(item.id);
                                    } else {
                                      next.remove(item.id);
                                    }
                                    ref
                                        .read(cartSelectionProvider('staff:$projectId').notifier)
                                        .state = next;
                                  },
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 64,
                              height: 64,
                              child: item.product.imageUrl != null
                                  ? Image.network(
                                      item.product.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) {
                                        final colors = AppColors.of(context);
                                        return ColoredBox(
                                          color: colors.imagePlaceholder,
                                          child: const Icon(Icons.image_outlined),
                                        );
                                      },
                                    )
                                  : ColoredBox(
                                      color: AppColors.of(context).imagePlaceholder,
                                      child: const Icon(Icons.image_outlined),
                                    ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (item.locked) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'В заказе',
                                    style:
                                        Theme.of(context).textTheme.labelMedium,
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  '${formatPrice(item.product.price)} / ${item.product.unit}'
                                  '${item.product.sellByPack ? ' · ${packAmountLabel(item.product.packSize, item.product.unit, item.quantity)} в ${item.quantity} уп.' : ''}',
                                ),
                                const SizedBox(height: 8),
                                if (!item.locked)
                                  QuantityStepper(
                                    quantity: item.quantity,
                                    onDecrement: item.quantity <= 1
                                        ? () => _remove(ref, item.id)
                                        : () => _update(
                                              ref,
                                              item.id,
                                              item.quantity - 1,
                                            ),
                                    onIncrement: () => _update(
                                      ref,
                                      item.id,
                                      item.quantity + 1,
                                    ),
                                  )
                                else
                                  Text(item.product.sellByPack
                                      ? '${item.quantity} уп.'
                                      : packAmountLabel(null, item.product.unit, item.quantity)),
                              ],
                            ),
                          ),
                          if (!item.locked)
                            IconButton(
                              onPressed: () => _remove(ref, item.id),
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (unlocked.isNotEmpty)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                selectedItems.isEmpty
                                    ? 'Выберите позиции'
                                    : 'К заказу · ${selectedItems.length}: ${formatPrice(selectedTotal)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            GhostButton(
                              label: 'Очистить',
                              onPressed: () async {
                                await ref
                                    .read(staffRepositoryProvider)
                                    .clearCart(projectId);
                                ref.invalidate(
                                  staffProjectCartProvider(projectId),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        PrimaryButton(
                          label: 'Оформить заказ',
                          onPressed: selectedItems.isEmpty
                              ? null
                              : () => context.push(
                                    AppRoutes.staffProjectCheckout(projectId),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _update(WidgetRef ref, String itemId, int quantity) async {
    await ref.read(staffRepositoryProvider).updateCartItem(
          widget.projectId,
          itemId: itemId,
          quantity: quantity,
        );
    ref.invalidate(staffProjectCartProvider(widget.projectId));
  }

  Future<void> _remove(WidgetRef ref, String itemId) async {
    await ref
        .read(staffRepositoryProvider)
        .removeCartItem(widget.projectId, itemId);
    ref.invalidate(staffProjectCartProvider(widget.projectId));
  }
}
