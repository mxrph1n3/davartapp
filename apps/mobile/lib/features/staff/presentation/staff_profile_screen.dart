import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/tab_page.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/router/app_router.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../profile/presentation/profile_notifier.dart';
import 'package:go_router/go_router.dart';

/// Minimal staff profile tab (settings + logout). Client-only menus hidden.
class StaffProfileScreen extends ConsumerWidget {
  const StaffProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final profileAsync = ref.watch(profileProvider);
    final phone = authState.user?.phone ?? '—';
    final name = profileAsync.value?.name ?? authState.user?.name;

    return TabPage(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const ScreenHeader(title: 'Профиль'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              AppAvatar(
                label: name?.isNotEmpty == true ? name! : phone,
                size: 72,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name ?? 'Сотрудник',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(phone, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      authState.user?.role == UserRole.admin
                          ? 'Админ Davart'
                          : 'Сотрудник Davart',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (authState.user?.role == UserRole.admin)
            ListItem(
              title: 'Пользователи',
              subtitle: 'Роли и аккаунты по номеру',
              leading: const Icon(Icons.admin_panel_settings_outlined),
              onTap: () => context.push(AppRoutes.adminUsers),
            ),
          ListItem(
            title: 'Активность',
            leading: const Icon(Icons.history),
            onTap: () => context.push(AppRoutes.staffAudit),
          ),
          ListItem(
            title: 'Настройки',
            leading: const Icon(Icons.settings_outlined),
            onTap: () => context.push(AppRoutes.settings),
          ),
          ListItem(
            title: 'Выйти',
            leading: const Icon(Icons.logout),
            onTap: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) context.go(AppRoutes.catalog);
            },
          ),
        ],
      ),
    );
  }
}
