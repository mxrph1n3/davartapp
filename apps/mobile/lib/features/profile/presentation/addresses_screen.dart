import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../auth/presentation/require_login.dart';
import '../data/profile_repository.dart';
import 'profile_notifier.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(authProvider).isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: AppBackButton(fallback: AppRoutes.profile),
          title: const Text('Адреса объектов'),
        ),
        body: const LoginRequiredView(
          subtitle: 'Чтобы сохранять адреса объектов',
        ),
      );
    }

    final addressesAsync = ref.watch(addressesProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppBackButton(
          fallback: profilePathForRole(ref.watch(authProvider).user?.role),
        ),
        title: const Text('Адреса объектов'),
        actions: [
          IconButton(
            onPressed: () => _openForm(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: addressesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить адреса',
          onRetry: () => ref.invalidate(addressesProvider),
        ),
        data: (addresses) {
          if (addresses.isEmpty) {
            return EmptyState(
              icon: Icons.location_on_outlined,
              title: 'Адресов пока нет',
              subtitle: 'Добавьте адрес для быстрого оформления заказов',
              actionLabel: 'Добавить адрес',
              onAction: () => _openForm(context, ref),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final address = addresses[index];
              return ListItem(
                title: address.label ?? 'Адрес',
                subtitle: address.formatted,
                badge: address.isDefault ? 'Основной' : null,
                leading: const Icon(Icons.location_on_outlined, size: 22),
                onTap: () => _openForm(context, ref, address: address),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    UserAddress? address,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddressFormSheet(address: address),
    );
    ref.invalidate(addressesProvider);
  }
}

class _AddressFormSheet extends ConsumerStatefulWidget {
  const _AddressFormSheet({this.address});

  final UserAddress? address;

  @override
  ConsumerState<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends ConsumerState<_AddressFormSheet> {
  late final TextEditingController _labelController;
  late final TextEditingController _cityController;
  late final TextEditingController _streetController;
  late final TextEditingController _buildingController;
  late final TextEditingController _apartmentController;
  var _isDefault = false;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.address?.label ?? '');
    _cityController = TextEditingController(text: widget.address?.city ?? '');
    _streetController = TextEditingController(text: widget.address?.street ?? '');
    _buildingController =
        TextEditingController(text: widget.address?.building ?? '');
    _apartmentController =
        TextEditingController(text: widget.address?.apartment ?? '');
    _isDefault = widget.address?.isDefault ?? false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _cityController.dispose();
    _streetController.dispose();
    _buildingController.dispose();
    _apartmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.screenPadding,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.screenPadding,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.address == null ? 'Новый адрес' : 'Редактировать адрес',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            AppInput(controller: _labelController, labelText: 'Название'),
            const SizedBox(height: AppSpacing.sm),
            AppInput(controller: _cityController, labelText: 'Город'),
            const SizedBox(height: AppSpacing.sm),
            AppInput(controller: _streetController, labelText: 'Улица'),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppInput(
                    controller: _buildingController,
                    labelText: 'Дом',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppInput(
                    controller: _apartmentController,
                    labelText: 'Кв.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Основной адрес',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  Switch.adaptive(
                    value: _isDefault,
                    onChanged: (value) => setState(() => _isDefault = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (widget.address != null)
                  GhostButton(
                    label: 'Удалить',
                    onPressed: () async {
                      await ref
                          .read(profileRepositoryProvider)
                          .deleteAddress(widget.address!.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                const Spacer(),
                SizedBox(
                  width: 140,
                  child: PrimaryButton(
                    label: 'Сохранить',
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final request = CreateAddressRequest(
      label: _labelController.text.trim().isEmpty
          ? null
          : _labelController.text.trim(),
      city: _cityController.text.trim(),
      street: _streetController.text.trim(),
      building: _buildingController.text.trim(),
      apartment: _apartmentController.text.trim().isEmpty
          ? null
          : _apartmentController.text.trim(),
      isDefault: _isDefault,
    );

    try {
      final repository = ref.read(profileRepositoryProvider);
      if (widget.address == null) {
        await repository.createAddress(request);
      } else {
        await repository.updateAddress(widget.address!.id, request);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
