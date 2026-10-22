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
import '../../projects/data/projects_repository.dart';
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
    Future<void>.delayed(Duration.zero, () {
      if (!mounted) return;
      ref.read(cartProvider.notifier).loadCart();
    });
  }

  Future<void> _assignToProject() async {
    final projects = (await ref.read(projectsRepositoryProvider).getProjects())
        .where((project) => !project.isDraft && !project.isShowcase)
        .toList();
    if (!mounted) return;
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала заполните анкету в разделе «Дизайн»'),
        ),
      );
      return;
    }

    late final String projectId;
    late final String projectName;
    if (projects.length == 1) {
      projectId = projects.first.id;
      projectName = projects.first.name;
    } else {
      final last = ref.read(lastCartProjectProvider);
      if (last != null && projects.any((project) => project.id == last.id)) {
        ref.read(activeProjectProvider.notifier).state = last;
      }
      final picked = await showProjectPickerSheet(
        context,
        ref,
        title: 'В какой проект добавить?',
      );
      if (picked == null || !mounted) return;
      projectId = picked.id;
      projectName = picked.name;
    }

    final selected = ref
            .read(cartProvider)
            .cart
            ?.items
            .where(
              (item) =>
                  !item.locked &&
                  ref.read(cartSelectionProvider('personal')).contains(item.id),
            )
            .toList() ??
        const <CartItem>[];
    if (selected.isEmpty) return;

    try {
      await ref.read(cartProvider.notifier).assignToProject(projectId, selected);
      ref.read(lastCartProjectProvider.notifier).state = ActiveProject(
        id: projectId,
        name: projectName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Добавлено в $projectName')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось добавить в проект')),
      );
    }
  }

  void _syncSelection(String scope, Cart cart) {
    final unlockedIds =
        cart.items.where((i) => !i.locked).map((i) => i.id).toSet();
    final current = ref.read(cartSelectionProvider(scope));
    final next = current.intersection(unlockedIds);
    if (next.isEmpty && unlockedIds.isNotEmpty) {
      ref.read(cartSelectionProvider(scope).notifier).state = unlockedIds;
    } else if (next.length != current.length) {
      ref.read(cartSelectionProvider(scope).notifier).state = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final state = ref.watch(cartProvider);
    final cart = state.cart;
    final selection = ref.watch(cartSelectionProvider('personal'));
    final personalItems =
        cart?.items.where((item) => !item.locked).toList() ??
            const <CartItem>[];
    final projectCarts = state.projectCarts
        .map(
          (project) => Cart(
            items: project.items.where((item) => !item.locked).toList(),
            total: project.total,
            itemCount: project.itemCount,
            projectId: project.projectId,
            projectName: project.projectName,
            ownerUserId: project.ownerUserId,
          ),
        )
        .where((item) => item.items.isNotEmpty)
        .toList();
    final projectSelections = {
      for (final project in projectCarts)
        if (project.projectId != null)
          project.projectId!: ref.watch(
            cartSelectionProvider('project:${project.projectId}'),
          ),
    };
    final hasPersonal = personalItems.isNotEmpty;
    final hasAnything = hasPersonal || projectCarts.isNotEmpty;
    final unlocked = cart?.items.where((i) => !i.locked).toList() ?? const [];
    final selectedItems =
        unlocked.where((i) => selection.contains(i.id)).toList();
    final selectedTotal =
        selectedItems.fold<double>(0, (sum, i) => sum + i.subtotal);

    if (cart != null || projectCarts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (cart != null) _syncSelection('personal', cart);
        for (final project in projectCarts) {
          final projectId = project.projectId;
          if (projectId != null) {
            _syncSelection('project:$projectId', project);
          }
        }
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
                      : !ref.watch(authProvider).isAuthenticated
                          ? const LoginRequiredView(
                              title: 'Войдите по номеру',
                              subtitle: 'Товары сохранятся в вашей корзине',
                            )
                          : !hasAnything
                              ? EmptyState(
                                  icon: Icons.shopping_bag_outlined,
                                  title: 'Корзина пуста',
                                  subtitle: 'Добавьте товары из каталога',
                                  actionLabel: 'В каталог',
                                  onAction: () => context.go(AppRoutes.catalog),
                                )
                              : ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.screenPadding,
                                    0,
                                    AppSpacing.screenPadding,
                                    AppSpacing.md,
                                  ),
                                  children: [
                                    if (hasPersonal && projectCarts.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: AppSpacing.md,
                                        ),
                                        child: Text(
                                          'Личная корзина',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                      ),
                                    for (var index = 0;
                                        index < personalItems.length;
                                        index++) ...[
                                      _personalLine(
                                        context,
                                        personalItems[index],
                                        selection,
                                      ),
                                      if (index != personalItems.length - 1)
                                        Divider(
                                          height: 24,
                                          color: colors.divider,
                                        ),
                                    ],
                                    for (final project in projectCarts) ...[
                                      Padding(
                                        padding: EdgeInsets.only(
                                          top: hasPersonal
                                              ? AppSpacing.xl
                                              : 0,
                                          bottom: AppSpacing.md,
                                        ),
                                        child: Text(
                                          (project.projectName ?? '').isEmpty
                                              ? 'Проект'
                                              : project.projectName!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                      ),
                                      for (var index = 0;
                                          index < project.items.length;
                                          index++) ...[
                                        _projectLine(
                                          context,
                                          project,
                                          project.items[index],
                                          projectSelections[project.projectId] ??
                                              const {},
                                        ),
                                        if (index != project.items.length - 1)
                                          Divider(
                                            height: 24,
                                            color: colors.divider,
                                          ),
                                      ],
                                      if (project.projectId != null) ...[
                                        const SizedBox(height: AppSpacing.md),
                                        PrimaryButton(
                                          label: 'Оформить заявку',
                                          onPressed: (projectSelections[
                                                          project.projectId] ??
                                                      const <String>{})
                                                  .isEmpty
                                              ? null
                                              : () => context.push(
                                                    '${AppRoutes.checkout}?projectId=${project.projectId}',
                                                  ),
                                        ),
                                      ],
                                    ],
                                  ],
                                ),
            ),
            if (hasPersonal && unlocked.isNotEmpty)
              _CartSummary(
                total: selectedTotal,
                selectedCount: selectedItems.length,
                onCheckout: selectedItems.isEmpty ? null : _assignToProject,
              ),
          ],
        ),
      ),
    );
  }

  Widget _personalLine(
    BuildContext context,
    CartItem item,
    Set<String> selection,
  ) {
    return _CartLineItem(
      item: item,
      selected: selection.contains(item.id),
      onSelected: item.locked
          ? null
          : (value) {
              final next = Set<String>.from(selection);
              if (value == true) {
                next.add(item.id);
              } else {
                next.remove(item.id);
              }
              ref.read(cartSelectionProvider('personal').notifier).state =
                  next;
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
              .updateQuantity(item.id, item.quantity + 1),
      onDecrement: item.locked
          ? null
          : item.quantity > 1
              ? () => ref
                  .read(cartProvider.notifier)
                  .updateQuantity(item.id, item.quantity - 1)
              : () => ref.read(cartProvider.notifier).removeItem(item.id),
      onRemove: item.locked
          ? null
          : () => ref.read(cartProvider.notifier).removeItem(item.id),
    );
  }

  Widget _projectLine(
    BuildContext context,
    Cart project,
    CartItem item,
    Set<String> selection,
  ) {
    final projectId = project.projectId;
    final scope = projectId == null ? null : 'project:$projectId';
    return _CartLineItem(
      item: item,
      selected: selection.contains(item.id),
      onSelected: item.locked || scope == null
          ? null
          : (value) {
              final next = Set<String>.from(selection);
              if (value == true) {
                next.add(item.id);
              } else {
                next.remove(item.id);
              }
              ref.read(cartSelectionProvider(scope).notifier).state = next;
            },
      onTap: () => context.push(
        productPathForRole(
          ref.read(authProvider).user?.role,
          item.product.id,
        ),
      ),
      onIncrement: item.locked || projectId == null
          ? null
          : () => ref.read(cartProvider.notifier).updateProjectQuantity(
                projectId,
                item.id,
                item.quantity + 1,
              ),
      onDecrement: item.locked || projectId == null
          ? null
          : item.quantity > 1
              ? () => ref.read(cartProvider.notifier).updateProjectQuantity(
                    projectId,
                    item.id,
                    item.quantity - 1,
                  )
              : () => ref
                  .read(cartProvider.notifier)
                  .removeProjectItem(projectId, item.id),
      onRemove: item.locked || projectId == null
          ? null
          : () => ref
              .read(cartProvider.notifier)
              .removeProjectItem(projectId, item.id),
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
          if (onSelected != null || locked)
            Checkbox(
              value: locked ? false : selected,
              onChanged: onSelected,
            )
          else
            const SizedBox(width: 8),
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
              label: 'Добавить в проект',
              onPressed: onCheckout,
            ),
          ],
        ),
      ),
    );
  }
}
