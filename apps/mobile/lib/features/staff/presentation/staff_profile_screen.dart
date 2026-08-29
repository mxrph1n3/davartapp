import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/tab_page.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../profile/presentation/profile_notifier.dart';
import '../../profile/presentation/settings_screen.dart';

/// Minimal staff profile tab. Client-only menus hidden.
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
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
                        authState.user?.canAssignRoles == true
                            ? 'Админ DAVart'
                            : 'Сотрудник DAVart',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (authState.user?.canAssignRoles == true)
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
            title: 'Личные данные',
            leading: const Icon(Icons.person_outline, size: 22),
            onTap: () => context.push(
              editProfilePathForRole(ref.read(authProvider).user?.role),
            ),
          ),
          const ProfileThemeSection(),
          const ProfileNotificationsSection(),
          const SizedBox(height: AppSpacing.xl),
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
