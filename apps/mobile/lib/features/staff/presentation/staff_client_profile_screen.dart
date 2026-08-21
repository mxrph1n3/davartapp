import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../commerce/presentation/project_picker_sheet.dart';
import '../../profile/data/profile_repository.dart';
import '../data/staff_repository.dart';
import 'working_client_provider.dart';

class StaffClientProfileScreen extends ConsumerWidget {
  const StaffClientProfileScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(staffClientProfileProvider(clientId));
    final addressesAsync = ref.watch(staffClientAddressesProvider(clientId));
    final projectsAsync = ref.watch(staffClientProjectsProvider(clientId));

    ref.listen(staffClientProfileProvider(clientId), (previous, next) {
      next.whenData((profile) {
        ref.read(workingClientProvider.notifier).state = WorkingClient(
          id: profile.id,
          displayName: profile.displayName,
          phone: profile.phone,
        );
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Клиент'),
        leading: IconButton(
          tooltip: 'К списку клиентов',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => popOrGo(context, AppRoutes.staffClients),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить клиента',
          onRetry: () => ref.invalidate(staffClientProfileProvider(clientId)),
        ),
        data: (profile) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(staffClientProfileProvider(clientId));
              ref.invalidate(staffClientAddressesProvider(clientId));
              ref.invalidate(staffClientProjectsProvider(clientId));
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                Row(
                  children: [
                    AppAvatar(label: profile.displayName, size: 64),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.phone,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (profile.email != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              profile.email!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  [
                    'проектов: ${profile.projectsCount}',
                    'адресов: ${profile.addressesCount}',
                    'в корзине: ${profile.cartItemsCount}',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                ListItem(
                  title: 'Корзина проекта',
                  subtitle: 'Выберите проект и откройте корзину',
                  leading: const Icon(Icons.shopping_bag_outlined, size: 22),
                  onTap: () async {
                    final projectId = await ensureActiveProject(
                      context,
                      ref,
                      staffClientId: clientId,
                      forcePicker: true,
                    );
                    if (projectId != null && context.mounted) {
                      context.push(AppRoutes.staffProjectCart(projectId));
                    }
                  },
                ),
                PrimaryButton(
                  label: 'Работать с корзиной в каталоге',
                  onPressed: () async {
                    ref.read(workingClientProvider.notifier).state =
                        WorkingClient(
                      id: profile.id,
                      displayName: profile.displayName,
                      phone: profile.phone,
                    );
                    final projectId = await ensureActiveProject(
                      context,
                      ref,
                      staffClientId: clientId,
                      forcePicker: true,
                    );
                    if (projectId != null && context.mounted) {
                      context.go(AppRoutes.staffCatalog);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Адреса объектов',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Добавить адрес',
                      onPressed: () => _addAddress(context, ref),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                addressesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => const Text('Не удалось загрузить адреса'),
                  data: (addresses) {
                    if (addresses.isEmpty) {
                      return Text(
                        'Адресов пока нет',
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    }
                    return Column(
                      children: addresses
                          .map(
                            (a) => ListItem(
                              title: a.label ?? 'Адрес',
                              subtitle: a.formatted,
                              badge: a.isDefault ? 'Основной' : null,
                              leading: const Icon(
                                Icons.location_on_outlined,
                                size: 22,
                              ),
                              showChevron: false,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Проекты',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                projectsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => const Text('Не удалось загрузить проекты'),
                  data: (projects) {
                    if (projects.isEmpty) {
                      return Text(
                        'Проектов пока нет',
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    }
                    return Column(
                      children: projects
                          .map(
                            (p) => ListItem(
                              title: p.name,
                              subtitle: [
                                p.statusLabel,
                                if (p.objectType != null) p.objectType!,
                              ].join(' · '),
                              leading: const Icon(
                                Icons.folder_outlined,
                                size: 22,
                              ),
                              onTap: () => context.push(
                                AppRoutes.staffClientBrief(
                                  clientId,
                                  p.id,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addAddress(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _StaffAddressFormSheet(clientId: clientId),
    );
    ref.invalidate(staffClientAddressesProvider(clientId));
    ref.invalidate(staffClientProfileProvider(clientId));
  }
}

class _StaffAddressFormSheet extends ConsumerStatefulWidget {
  const _StaffAddressFormSheet({required this.clientId});

  final String clientId;

  @override
  ConsumerState<_StaffAddressFormSheet> createState() =>
      _StaffAddressFormSheetState();
}

class _StaffAddressFormSheetState
    extends ConsumerState<_StaffAddressFormSheet> {
  final _labelController = TextEditingController();
  final _cityController = TextEditingController();
  final _streetController = TextEditingController();
  final _buildingController = TextEditingController();
  final _apartmentController = TextEditingController();
  var _isDefault = false;
  var _isSaving = false;

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
        bottom:
            MediaQuery.of(context).viewInsets.bottom + AppSpacing.screenPadding,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Новый адрес клиента',
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
            Row(
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
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Сохранить',
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(staffRepositoryProvider).createAddress(
            widget.clientId,
            CreateAddressRequest(
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
            ),
          );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
