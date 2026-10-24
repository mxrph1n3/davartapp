import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/top_notice.dart';
import '../../auth/presentation/require_login.dart';
import '../../catalog/presentation/widgets/shop_cart.dart';
import '../../profile/data/profile_repository.dart';
import '../data/commerce_models.dart';
import '../data/commerce_repository.dart';
import 'cart_screen.dart' show cartScope;
import 'cart_selection_provider.dart';
import 'commerce_notifier.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, this.projectId});

  final String? projectId;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _addressController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!await promptLogin(context, ref)) return;
    if (!mounted) return;
    if (!_formKey.currentState!.validate()) return;

    final projectId = widget.projectId;
    final cart = _cart(ref.read(cartProvider));
    final selection = ref.read(cartSelectionProvider(cartScope(projectId)));
    final unlockedIds =
        cart?.items.where((i) => !i.locked).map((i) => i.id).toSet() ?? {};
    final cartItemIds = selection.intersection(unlockedIds).toList();
    if (cartItemIds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите позиции для заказа')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(commerceRepositoryProvider).createOrder(
            projectId: projectId,
            cartItemIds: cartItemIds,
            address: _addressController.text.trim(),
            comment: _commentController.text.trim(),
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось оформить заказ')),
        );
      }
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }

    ref.read(cartSelectionProvider(cartScope(projectId)).notifier).state = {};
    ref.invalidate(ordersProvider);
    await ref.read(cartProvider.notifier).loadCart();

    if (!mounted) return;
    showTopNotice(context, 'Заказ оформлен. Менеджер свяжется с вами');
    popOrGo(context, AppRoutes.cart);
  }

  /// Personal cart without [CheckoutScreen.projectId], otherwise that project's cart.
  Cart? _cart(CartState state) {
    final projectId = widget.projectId;
    if (projectId == null) return state.cart;
    for (final cart in state.projectCarts) {
      if (cart.projectId == projectId) return cart;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    // The saved default address goes straight into the field.
    Future<void>.microtask(() async {
      try {
        final list = await ref.read(profileRepositoryProvider).getAddresses();
        if (!mounted || list.isEmpty || _addressController.text.isNotEmpty) return;
        final address = list.firstWhere((a) => a.isDefault, orElse: () => list.first);
        _addressController.text = address.formatted;
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = _cart(ref.watch(cartProvider));
    final selection = ref.watch(cartSelectionProvider(cartScope(widget.projectId)));
    final selected = cart?.items
            .where((i) => !i.locked && selection.contains(i.id))
            .toList() ??
        const [];
    final total = selected.fold<double>(0, (sum, i) => sum + i.subtotal);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppBackButton(fallback: AppRoutes.cart),
        title: const Text('Оформление заказа'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  Text(
                    'Товаров: ${selected.length} · ${formatPrice(total)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...selected.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${item.product.name} — ${item.product.sellByPack ? '${item.quantity} уп. (${packAmountLabel(item.product.packSize, item.product.unit, item.quantity)})' : packAmountLabel(null, item.product.unit, item.quantity)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppInput(
                    controller: _addressController,
                    hintText: 'Адрес доставки',
                    validator: (value) {
                      if (value == null || value.trim().length < 5) {
                        return 'Введите полный адрес';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppInput(
                    controller: _commentController,
                    hintText: 'Комментарий (необязательно)',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.md,
                AppSpacing.screenPadding,
                AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
              ),
              child: PrimaryButton(
                label: 'Оформить заказ',
                isLoading: _isSubmitting,
                onPressed: _isSubmitting || selected.isEmpty ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
