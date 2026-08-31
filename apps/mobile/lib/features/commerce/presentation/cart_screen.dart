import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/tab_page.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../auth/presentation/require_login.dart';
import '../data/commerce_models.dart';
import 'active_project_provider.dart';
import 'cart_selection_provider.dart';
import 'commerce_notifier.dart';
import 'project_picker_sheet.dart';

/// Cart tab inside [MainShell] — bottom nav stays visible and tappable.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration.zero, () async {
      if (!mounted) return;
      if (ref.read(authProvider).isAuthenticated) {
        await ensureActiveProject(context, ref, silent: true);
      }
      if (mounted) ref.read(cartProvider.notifier).loadCart();
    });
  }

  void _syncSelection(Cart cart) {
    final unlockedIds =
        cart.items.where((i) => !i.locked).map((i) => i.id).toSet();
    final current = ref.read(cartSelectionProvider);
    final next = current.intersection(unlockedIds);
    if (next.isEmpty && unlockedIds.isNotEmpty) {
      ref.read(cartSelectionProvider.notifier).state = unlockedIds;
    } else if (next.length != current.length) {
      ref.read(cartSelectionProvider.notifier).state = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final state = ref.watch(cartProvider);
    final cart = state.cart;
    final selection = ref.watch(cartSelectionProvider);
    final hasItems = cart != null && cart.items.isNotEmpty;
    final unlocked = cart?.items.where((i) => !i.locked).toList() ?? const [];
    final selectedItems =
        unlocked.where((i) => selection.contains(i.id)).toList();
    final selectedTotal =
        selectedItems.fold<double>(0, (sum, i) => sum + i.subtotal);

    if (cart != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncSelection(cart);
      });
    }

    return TabPage(
      child: SizedBox.expand(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader(title: 'Корзина'),
            Expanded(
              child: state.isLoading && cart == null
                  ? const Center(child: CircularProgressIndicator())
                  : state.errorMessage != null && cart == null
                      ? ErrorState(
                          message: state.errorMessage!,
                          onRetry: () =>
                              ref.read(cartProvider.notifier).loadCart(),
                        )
                      : ref.watch(activeProjectProvider) == null
                          ? ref.watch(authProvider).isAuthenticated
                              ? EmptyState(
                                  icon: Icons.folder_outlined,
                                  title: 'Выберите проект',
                                  subtitle:
                                      'Корзина привязана к проекту — выберите его',
                                  actionLabel: 'Выбрать проект',
                                  onAction: () => ensureActiveProject(
                                    context,
                                    ref,
                                    forcePicker: true,
                                  ),
                                )
                              : const LoginRequiredView(
                                  title: 'Войдите по номеру',
                                  subtitle:
                                      'Товары сохранятся в корзине вашего проекта',
                                )
                          : !hasItems
                              ? EmptyState(
                                  icon: Icons.shopping_bag_outlined,
                                  title: 'Корзина пуста',
                                  subtitle: 'Добавьте товары из каталога',
                                  actionLabel: 'В каталог',
                                  onAction: () => context.go(AppRoutes.catalog),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.screenPadding,
                                    0,
                                    AppSpacing.screenPadding,
                                    AppSpacing.md,
                                  ),
                                  itemCount: cart.items.length,
                                  separatorBuilder: (_, _) => Divider(
                                    height: 24,
                                    color: colors.divider,
                                  ),
                                  itemBuilder: (context, index) {
                                    final item = cart.items[index];
                                    final selected =
                                        selection.contains(item.id);
                                    return _CartLineItem(
                                      item: item,
                                      selected: selected,
                                      onSelected: item.locked
                                          ? null
                                          : (value) {
                                              final next =
                                                  Set<String>.from(selection);
                                              if (value == true) {
                                                next.add(item.id);
                                              } else {
                                                next.remove(item.id);
                                              }
                                              ref
                                                  .read(
                                                    cartSelectionProvider
                                                        .notifier,
                                                  )
                                                  .state = next;
                                            },
                                      onTap: () => context.push(
                                        productPathForRole(
                                          ref.read(authProvider).user?.role,
                                          item.product.id,
                                        ),
                                      ),
                                      onIncrement: item.locked
                                          ? null
                                          : () => ref
                                              .read(cartProvider.notifier)
                                              .updateQuantity(
                                                item.id,
                                                item.quantity + 1,
                                              ),
                                      onDecrement: item.locked
                                          ? null
                                          : item.quantity > 1
                                              ? () => ref
                                                  .read(cartProvider.notifier)
                                                  .updateQuantity(
                                                    item.id,
                                                    item.quantity - 1,
                                                  )
                                              : () => ref
                                                  .read(cartProvider.notifier)
                                                  .removeItem(item.id),
                                      onRemove: item.locked
                                          ? null
                                          : () => ref
                                              .read(cartProvider.notifier)
                                              .removeItem(item.id),
                                    );
                                  },
                                ),
            ),
            if (hasItems && unlocked.isNotEmpty)
              _CartSummary(
                total: selectedTotal,
                selectedCount: selectedItems.length,
                onCheckout: selectedItems.isEmpty
                    ? null
                    : () => context.push(AppRoutes.checkout),
              ),
          ],
        ),
      ),
    );
  }
}

class _CartLineItem extends StatelessWidget {
  const _CartLineItem({
    required this.item,
    required this.selected,
    required this.onSelected,
    required this.onTap,
    this.onIncrement,
    this.onDecrement,
    this.onRemove,
  });

  final CartItem item;
  final bool selected;
  final ValueChanged<bool?>? onSelected;
  final VoidCallback onTap;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final locked = item.locked;

    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: locked ? false : selected,
            onChanged: onSelected,
          ),
          GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: AppRadius.imageRadius,
              child: SizedBox(
                width: 80,
                height: 80,
                child: item.product.imageUrl != null
                    ? Image.network(item.product.imageUrl!, fit: BoxFit.cover)
                    : ColoredBox(
                        color: colors.imagePlaceholder,
                        child: const Icon(Icons.image_outlined),
                      ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    item.product.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                if (locked) ...[
                  const SizedBox(height: 4),
                  Text(
                    'В заказе',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  formatPrice(item.product.price),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                if (!locked && onIncrement != null && onDecrement != null)
                  QuantityStepper(
                    quantity: item.quantity,
                    onIncrement: onIncrement!,
                    onDecrement: onDecrement!,
                  )
                else
                  Text(
                    '${item.quantity} шт.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 20),
              color: colors.textSecondary,
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({
    required this.total,
    required this.selectedCount,
    required this.onCheckout,
  });

  final double total;
  final int selectedCount;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: colors.background,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.md,
          AppSpacing.screenPadding,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.divider)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedCount == 0
                      ? 'Выберите позиции'
                      : 'К заказу · $selectedCount',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  formatPrice(total),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Оформить заказ',
              onPressed: onCheckout,
            ),
          ],
        ),
      ),
    );
  }
}
