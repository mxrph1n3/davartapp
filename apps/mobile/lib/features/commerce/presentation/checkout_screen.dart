import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../auth/presentation/require_login.dart';
import '../data/commerce_models.dart';
import '../data/commerce_repository.dart';
import 'cart_selection_provider.dart';
import 'commerce_notifier.dart';
import 'project_picker_sheet.dart';

final _priceFormat = NumberFormat.currency(locale: 'ru_RU', symbol: '₽');

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

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

    final projectId = await ensureActiveProject(context, ref);
    if (projectId == null) return;

    final cart = ref.read(cartProvider).cart;
    final selection = ref.read(cartSelectionProvider);
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

    late final Order order;
    try {
      order = await ref.read(commerceRepositoryProvider).createOrder(
            projectId: projectId,
            cartItemIds: cartItemIds,
            address: _addressController.text.trim(),
            comment: _commentController.text.trim(),
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить заявку')),
        );
      }
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }

    ref.read(cartSelectionProvider.notifier).state = {};
    ref.invalidate(ordersProvider);
    await ref.read(cartProvider.notifier).loadCart();

    if (!mounted) return;
    context.pushReplacement(AppRoutes.orderDetail(order.id));
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider).cart;
    final selection = ref.watch(cartSelectionProvider);
    final selected = cart?.items
            .where((i) => !i.locked && selection.contains(i.id))
            .toList() ??
        const [];
    final total = selected.fold<double>(0, (sum, i) => sum + i.subtotal);
    final qty = selected.fold<int>(0, (sum, i) => sum + i.quantity);

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
                    'Позиций: ${selected.length} · товаров: $qty',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Сумма: ${_priceFormat.format(total)}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...selected.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${item.product.name} × ${item.quantity}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Это заявка для студии. Оплата в приложении не списывается — менеджер свяжется с вами.',
                    style: Theme.of(context).textTheme.bodySmall,
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
                label: 'Отправить заявку',
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
