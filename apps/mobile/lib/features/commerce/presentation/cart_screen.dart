import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/tab_page.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/top_notice.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../auth/presentation/require_login.dart';
import '../../catalog/presentation/widgets/shop_cart.dart';
import '../../catalog/presentation/widgets/shop_widgets.dart';
import '../../chat/data/chat_repository.dart';
import '../../projects/data/projects_models.dart';
import '../../projects/data/projects_repository.dart';
import '../data/commerce_models.dart';
import 'cart_selection_provider.dart';
import 'commerce_notifier.dart';

/// The client's projects — one cart tab each, even while the designer has not filled it yet.
final cartProjectsProvider = FutureProvider.autoDispose<List<Project>>((ref) async {
  if (!ref.watch(authProvider).isAuthenticated) return const [];
  final projects = await ref.watch(projectsRepositoryProvider).getProjects();
  return projects.where((p) => !p.isDraft && !p.isShowcase).toList();
});

/// Open tab: null — «Личная», otherwise a project id.
final cartTabProvider = StateProvider<String?>((ref) => null);

String cartScope(String? projectId) => projectId == null ? 'personal' : 'project:$projectId';

/// Cart tab inside [MainShell]: «Личная» + a tab per project (the project cart is the
/// designer's подборка). Nothing is selected on open; orders go to the complectation
/// department without payment.
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cartProvider);
    final authed = ref.watch(authProvider).isAuthenticated;
    final projects = ref.watch(cartProjectsProvider).value ?? const <Project>[];
    var tab = ref.watch(cartTabProvider);
    if (tab != null && !projects.any((p) => p.id == tab)) tab = null;

    Widget body;
    if (!authed) {
      body = const LoginRequiredView(title: 'Войдите по номеру', subtitle: 'Товары сохранятся в вашей корзине');
    } else if (state.isLoading && state.cart == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.errorMessage != null && state.cart == null) {
      body = ErrorState(message: state.errorMessage!, onRetry: () => ref.read(cartProvider.notifier).loadCart());
    } else {
      body = _CartTab(projectId: tab, projects: projects);
    }

    return TabPage(
      child: SizedBox.expand(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader(title: 'Корзина'),
            if (authed && projects.isNotEmpty)
              _Tabs(
                selected: tab,
                projects: projects,
                counts: {
                  null: _lineCount(state.cart),
                  for (final p in projects) p.id: _lineCount(_projectCart(state, p.id)),
                },
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

int _lineCount(Cart? cart) => cart?.items.where((i) => !i.locked).length ?? 0;

Cart? _projectCart(CartState state, String projectId) {
  for (final cart in state.projectCarts) {
    if (cart.projectId == projectId) return cart;
  }
  return null;
}

class _Tabs extends ConsumerWidget {
  const _Tabs({required this.selected, required this.projects, required this.counts});

  final String? selected;
  final List<Project> projects;
  final Map<String?, int> counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);

    Widget chip(String? id, String label) {
      final active = id == selected;
      final n = counts[id] ?? 0;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: active ? colors.textPrimary : colors.surfaceMuted,
          borderRadius: BorderRadius.circular(19),
          child: InkWell(
            borderRadius: BorderRadius.circular(19),
            onTap: () => ref.read(cartTabProvider.notifier).state = id,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                child: Text(
                  n > 0 ? '$label · $n' : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: active ? colors.background : colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        children: [chip(null, 'Личная'), for (final p in projects) chip(p.id, p.name.isEmpty ? 'Проект' : p.name)],
      ),
    );
  }
}

class _CartTab extends ConsumerWidget {
  const _CartTab({required this.projectId, required this.projects});

  /// null — personal cart.
  final String? projectId;
  final List<Project> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final state = ref.watch(cartProvider);
    final cart = projectId == null ? state.cart : _projectCart(state, projectId!);
    final items = cart?.items.where((i) => !i.locked).toList() ?? const <CartItem>[];
    final scope = cartScope(projectId);
    final ids = items.map((i) => i.id).toSet();
    final selection = ref.watch(cartSelectionProvider(scope)).intersection(ids);
    final selected = items.where((i) => selection.contains(i.id)).toList();
    final total = selected.fold<double>(0, (sum, i) => sum + i.subtotal);
    final allSelected = items.isNotEmpty && selection.length == items.length;

    void setSelection(Set<String> next) => ref.read(cartSelectionProvider(scope).notifier).state = next;

    if (items.isEmpty) {
      return projectId == null
          ? EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Корзина пуста',
              subtitle: 'Добавьте товары из каталога',
              actionLabel: 'В каталог',
              onAction: () => context.go(AppRoutes.catalog),
            )
          : const EmptyState(
              icon: Icons.assignment_outlined,
              title: 'Корзину проекта собирает дизайнер',
              subtitle:
                  'Товары появятся здесь, когда дизайнер их подберёт. '
                  'Свои варианты можно предложить из личной корзины.',
            );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => setSelection(allSelected ? <String>{} : ids),
                icon: _SelectBox(checked: allSelected, partial: selection.isNotEmpty && !allSelected),
                label: Text(
                  allSelected ? 'Снять все' : 'Выбрать все',
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.5),
                ),
              ),
              const Spacer(),
              if (selection.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _removeSelected(context, ref, selection.toList()),
                  icon: Icon(Icons.delete_outline, size: 20, color: colors.textSecondary),
                  label: Text(
                    'Удалить (${selection.length})',
                    style: TextStyle(color: colors.textSecondary, fontSize: 14.5),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(cartProvider.notifier).loadCart(),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                return _CartLine(
                  item: item,
                  checked: selection.contains(item.id),
                  onCheck: () {
                    final next = {...selection};
                    if (!next.remove(item.id)) next.add(item.id);
                    setSelection(next);
                  },
                  onQuantity: (q) => projectId == null
                      ? ref.read(cartProvider.notifier).updateQuantity(item.id, q)
                      : ref.read(cartProvider.notifier).updateProjectQuantity(projectId!, item.id, q),
                  onRemove: () => projectId == null
                      ? ref.read(cartProvider.notifier).removeItem(item.id)
                      : ref.read(cartProvider.notifier).removeProjectItem(projectId!, item.id),
                  onOpen: () => context.push(productPathForRole(ref.read(authProvider).user?.role, item.product.id)),
                );
              },
            ),
          ),
        ),
        _Summary(
          count: selected.length,
          total: total,
          showPropose: projectId == null && projects.isNotEmpty,
          onPropose: selected.isEmpty ? null : () => _propose(context, ref, selected),
          onCheckout: selected.isEmpty
              ? null
              : () =>
                    context.push(projectId == null ? AppRoutes.checkout : '${AppRoutes.checkout}?projectId=$projectId'),
        ),
      ],
    );
  }

  Future<void> _removeSelected(BuildContext context, WidgetRef ref, List<String> ids) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ids.length == 1 ? 'Удалить товар?' : 'Удалить выбранные товары (${ids.length})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(cartProvider.notifier).removeItems(projectId, ids);
      ref.read(cartSelectionProvider(cartScope(projectId)).notifier).state = {};
    } catch (_) {
      if (context.mounted) showTopNotice(context, 'Не удалось удалить товары');
    }
  }

  /// «Предложить в проект»: the chosen goods go to the project chat for the designer to approve.
  Future<void> _propose(BuildContext context, WidgetRef ref, List<CartItem> items) async {
    final project = projects.length == 1 ? projects.first : await _pickProject(context);
    if (project == null) return;
    try {
      final chats = ref.read(chatRepositoryProvider);
      final chat = await chats.getProjectChat(project.id);
      await chats.sendMessage(
        chatId: chat.id,
        type: 'text',
        content: items.length == 1
            ? 'Предлагаю добавить в проект этот товар:'
            : 'Предлагаю добавить в проект эти товары (${items.length}):',
      );
      for (final item in items) {
        final p = item.product;
        await chats.sendMessage(
          chatId: chat.id,
          type: 'product',
          productId: p.id,
          content: p.sellByPack
              ? '${item.quantity} уп. · ${packAmountLabel(p.packSize, p.unit, item.quantity)}'
              : packAmountLabel(null, p.unit, item.quantity),
        );
      }
      ref.read(cartSelectionProvider(cartScope(null)).notifier).state = {};
      if (context.mounted) showTopNotice(context, 'Отправлено дизайнеру в чат проекта');
    } catch (_) {
      if (context.mounted) showTopNotice(context, 'Не удалось отправить предложение');
    }
  }

  Future<Project?> _pickProject(BuildContext context) {
    return showModalBottomSheet<Project>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('В какой проект предложить?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            for (final p in projects) ListTile(title: Text(p.name), onTap: () => Navigator.pop(ctx, p)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Empty rounded square by default; yellow with a check when chosen.
class _SelectBox extends StatelessWidget {
  const _SelectBox({required this.checked, this.partial = false});

  final bool checked;
  final bool partial;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = colors.accent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: checked || partial ? accent : colors.border, width: 1.6),
      ),
      child: checked
          ? const Icon(Icons.check, size: 16, color: Colors.black)
          : partial
          ? Center(child: Container(width: 10, height: 2, color: accent))
          : null,
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({
    required this.item,
    required this.checked,
    required this.onCheck,
    required this.onQuantity,
    required this.onRemove,
    required this.onOpen,
  });

  final CartItem item;
  final bool checked;
  final VoidCallback onCheck;
  final ValueChanged<int> onQuantity;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final p = item.product;
    final qty = item.quantity;
    final placeholder = ColoredBox(color: colors.imagePlaceholder);

    Widget step(bool plus, VoidCallback? onTap) => InkResponse(
      onTap: onTap,
      radius: 18,
      child: SizedBox.square(
        dimension: 34,
        child: Center(child: AccentGlyph(plus: plus)),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkResponse(
            onTap: onCheck,
            radius: 22,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 26, 10, 26),
              child: _SelectBox(checked: checked),
            ),
          ),
          GestureDetector(
            onTap: onOpen,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.square(
                dimension: 74,
                child: (p.imageUrl ?? '').isEmpty
                    ? placeholder
                    : Image.network(p.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onOpen,
                  child: Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatPrice(p.price)} / ${p.unit}'
                  '${p.sellByPack && p.packSize != null ? ' · ${packAmountLabel(p.packSize, p.unit, 1)} в уп.' : ''}',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    step(false, qty > 1 ? () => onQuantity(qty - 1) : onRemove),
                    SizedBox(
                      width: 52,
                      child: Column(
                        children: [
                          Text(
                            p.sellByPack ? '$qty уп.' : packAmountLabel(null, p.unit, qty),
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.textPrimary),
                          ),
                          if (p.sellByPack && p.packSize != null)
                            Text(
                              packAmountLabel(p.packSize, p.unit, qty),
                              style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    step(true, qty < 99 ? () => onQuantity(qty + 1) : null),
                    const Spacer(),
                    Text(
                      formatPrice(item.subtotal),
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: colors.textPrimary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.count,
    required this.total,
    required this.onCheckout,
    required this.onPropose,
    required this.showPropose,
  });

  final int count;
  final double total;
  final VoidCallback? onCheckout;
  final VoidCallback? onPropose;
  final bool showPropose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = shopAccentLine(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  count == 0 ? 'Отметьте товары для заказа' : 'Выбрано: $count',
                  style: TextStyle(fontSize: 15, color: count == 0 ? colors.textSecondary : colors.textPrimary),
                ),
              ),
              if (count > 0)
                Text(
                  formatPrice(total),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colors.textPrimary),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (showPropose) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onPropose,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      side: BorderSide(color: onPropose == null ? colors.border : accent, width: 1.5),
                      foregroundColor: colors.textPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Предложить в проект', style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: onCheckout,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Оформить заказ', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
