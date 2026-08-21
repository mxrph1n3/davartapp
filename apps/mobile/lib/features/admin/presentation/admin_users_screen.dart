import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/data/auth_repository.dart' show UserRole;
import '../../auth/presentation/auth_notifier.dart';
import '../data/admin_repository.dart';

final adminUsersProvider =
    FutureProvider.autoDispose.family<AdminUsersPage, String>((ref, q) {
  return ref.watch(adminRepositoryProvider).listUsers(q: q.isEmpty ? null : q);
});

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _search = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?.role;
    if (role != UserRole.admin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Пользователи')),
        body: const Center(child: Text('Доступно только админу')),
      );
    }

    final async = ref.watch(adminUsersProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Пользователи'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => popOrGo(context, AppRoutes.staffProfile),
        ),
        actions: [
          IconButton(
            tooltip: 'Создать аккаунт',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.sm,
              AppSpacing.screenPadding,
              AppSpacing.sm,
            ),
            child: AppInput(
              controller: _search,
              hintText: 'Поиск по имени или телефону',
              onChanged: (value) {
                setState(() => _query = value.trim());
              },
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorState(
                message: _dioMessage(error),
                onRetry: () => ref.invalidate(adminUsersProvider(_query)),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.group_outlined,
                    title: 'Никого нет',
                    subtitle: 'Создайте аккаунт по номеру телефона',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(adminUsersProvider(_query)),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    itemCount: page.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = page.items[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          user.name?.isNotEmpty == true
                              ? user.name!
                              : user.phone,
                        ),
                        subtitle: Text(
                          '${user.phone}\n${adminRoleLabel(user.role)}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.edit_outlined, size: 20),
                        onTap: () => _openEditor(user: user),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textPrimary,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Новый аккаунт'),
      ),
    );
  }

  Future<void> _openEditor({AdminUser? user}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AdminUserEditorSheet(user: user),
    );
    if (changed == true && mounted) {
      ref.invalidate(adminUsersProvider(_query));
    }
  }
}

class _AdminUserEditorSheet extends ConsumerStatefulWidget {
  const _AdminUserEditorSheet({this.user});

  final AdminUser? user;

  @override
  ConsumerState<_AdminUserEditorSheet> createState() =>
      _AdminUserEditorSheetState();
}

class _AdminUserEditorSheetState extends ConsumerState<_AdminUserEditorSheet> {
  late final TextEditingController _phone;
  late final TextEditingController _name;
  late UserRole _role;
  var _saving = false;

  bool get _isCreate => widget.user == null;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: widget.user?.phone ?? '+7');
    _name = TextEditingController(text: widget.user?.name ?? '');
    _role = widget.user?.role ?? UserRole.client;
  }

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        AppSpacing.screenPadding + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isCreate ? 'Новый аккаунт' : 'Редактировать',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          AppInput(
            controller: _phone,
            hintText: '+79001234567',
            keyboardType: TextInputType.phone,
            labelText: 'Телефон',
          ),
          const SizedBox(height: AppSpacing.sm),
          AppInput(
            controller: _name,
            hintText: 'Имя',
            labelText: 'Имя',
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Роль', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final role in UserRole.values)
                ChoiceChip(
                  label: Text(adminRoleLabel(role)),
                  selected: _role == role,
                  onSelected: (_) => setState(() => _role = role),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: _isCreate ? 'Создать' : 'Сохранить',
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final phone = _phone.text.trim();
    if (!RegExp(r'^\+7\d{10}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Телефон в формате +7XXXXXXXXXX')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final name = _name.text.trim();
      if (_isCreate) {
        await repo.createUser(
          phone: phone,
          role: _role,
          name: name.isEmpty ? null : name,
        );
      } else {
        await repo.updateUser(
          userId: widget.user!.id,
          phone: phone,
          name: name,
          role: _role,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_dioMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String _dioMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    if (data is Map && data['message'] is List) {
      return (data['message'] as List).join(', ');
    }
  }
  return 'Не удалось сохранить';
}
