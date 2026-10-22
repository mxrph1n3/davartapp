import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../commerce/data/commerce_models.dart';
import '../../commerce/presentation/active_project_provider.dart';
import '../../commerce/presentation/cart_selection_provider.dart';
import '../data/staff_repository.dart';
import 'staff_cart_actions.dart';
import 'working_client_provider.dart';

final _priceFormat = NumberFormat.currency(locale: 'ru_RU', symbol: '₽');

class StaffCheckoutScreen extends ConsumerStatefulWidget {
  const StaffCheckoutScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<StaffCheckoutScreen> createState() =>
      _StaffCheckoutScreenState();
}

class _StaffCheckoutScreenState extends ConsumerState<StaffCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _clientId;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration.zero, _bootstrap);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final active = ref.read(activeProjectProvider);
    final working = ref.read(workingClientProvider);
    var clientId = active?.ownerClientId ?? working?.id;

    try {
      final cart =
          await ref.read(staffRepositoryProvider).getCart(widget.projectId);
      clientId ??= cart.ownerUserId;
      if (active == null && cart.projectName != null) {
        ref.read(activeProjectProvider.notifier).state = ActiveProject(
          id: widget.projectId,
          name: cart.projectName!,
          ownerClientId: clientId,
        );
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _clientId = clientId);
    if (clientId != null) await _loadDefaultAddress(clientId);
  }

  Future<void> _loadDefaultAddress(String clientId) async {
    try {
      final addresses =
          await ref.read(staffRepositoryProvider).getAddresses(clientId);
      if (!mounted || addresses.isEmpty) return;
      final preferred = addresses.firstWhere(
        (a) => a.isDefault,
        orElse: () => addresses.first,
      );
      if (_addressController.text.trim().isEmpty) {
        _addressController.text = preferred.formatted;
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final cart = ref.read(staffProjectCartProvider(widget.projectId)).valueOrNull;
    final selection = ref.read(cartSelectionProvider('staff:${widget.projectId}'));
    final unlockedIds =
        cart?.items.where((i) => !i.locked).map((i) => i.id).toSet() ?? {};
    final cartItemIds = selection.intersection(unlockedIds).toList();
    if (cartItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите позиции для заказа')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    late final Order order;
    try {
      order = await ref.read(staffRepositoryProvider).createOrder(
            widget.projectId,
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

    ref.read(cartSelectionProvider('staff:${widget.projectId}').notifier).state = {};
    ref.invalidate(staffProjectCartProvider(widget.projectId));
    final clientId = _clientId ?? order.userId;
    if (clientId != null) {
      ref.invalidate(staffClientProfileProvider(clientId));
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Заявка отправлена')),
    );
    if (clientId != null) {
      context.go(AppRoutes.staffClientOrder(clientId, order.id));
    } else {
      context.pop();
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(staffProjectCartProvider(widget.projectId));
    final clientId = _clientId;
    final addressesAsync = clientId == null
        ? null
        : ref.watch(staffClientAddressesProvider(clientId));
    final project = ref.watch(activeProjectProvider);
    final label = project?.id == widget.projectId
        ? project!.name
        : 'проект';

    return Scaffold(
      appBar: AppBar(
        title: Text('Заказ · $label'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => popOrGo(
            context,
            AppRoutes.staffProjectCart(widget.projectId),
          ),
        ),
      ),
      body: cartAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить корзину',
          onRetry: () =>
              ref.invalidate(staffProjectCartProvider(widget.projectId)),
        ),
        data: (cart) {
          final selection = ref.watch(cartSelectionProvider('staff:${widget.projectId}'));
          final selected = cart.items
              .where((i) => !i.locked && selection.contains(i.id))
              .toList();
          final total =
              selected.fold<double>(0, (sum, i) => sum + i.subtotal);
          final qty = selected.fold<int>(0, (sum, i) => sum + i.quantity);

          if (selected.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Нет выбранных позиций',
              subtitle: 'Вернитесь в корзину и отметьте товары',
              actionLabel: 'К корзине',
              onAction: () => context.pop(),
            );
          }

          return Form(
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
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${item.product.name} × ${item.quantity}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Адрес объекта',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (addressesAsync != null)
                        addressesAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (addresses) {
                            if (addresses.isEmpty) {
                              return Text(
                                'У клиента нет сохранённых адресов — введите вручную',
                                style: Theme.of(context).textTheme.bodySmall,
                              );
                            }
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: addresses
                                  .map(
                                    (a) => ActionChip(
                                      label: Text(a.label ?? a.formatted),
                                      onPressed: () {
                                        _addressController.text = a.formatted;
                                      },
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                      const SizedBox(height: AppSpacing.md),
                      AppInput(
                        controller: _addressController,
                        hintText: 'Адрес доставки / объекта',
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
                    label: 'Оформить за клиента',
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
