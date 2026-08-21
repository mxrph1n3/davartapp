import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/settings/settings_notifier.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../auth/presentation/require_login.dart';
import 'profile_notifier.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(authProvider).isAuthenticated;
    final themeModeAsync = ref.watch(themeModeProvider);
    final profileAsync = isAuthenticated ? ref.watch(profileProvider) : null;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppBackButton(
          fallback: profilePathForRole(ref.watch(authProvider).user?.role),
        ),
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const SectionTitle(title: 'Аккаунт'),
          ListItem(
            title: 'Личные данные',
            subtitle: 'Имя и email',
            leading: const Icon(Icons.person_outline, size: 22),
            onTap: () async {
              if (!await promptLogin(context, ref)) return;
              if (context.mounted) context.push(AppRoutes.editProfile);
            },
          ),
          ListItem(
            title: 'Адреса объектов',
            subtitle: 'Адреса ваших объектов',
            leading: const Icon(Icons.location_on_outlined, size: 22),
            onTap: () async {
              if (!await promptLogin(context, ref)) return;
              if (context.mounted) context.push(AppRoutes.addresses);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          const SectionTitle(title: 'Тема'),
          themeModeAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (themeMode) {
              final current = switch (themeMode) {
                ThemeMode.light => AppThemeMode.light,
                ThemeMode.dark => AppThemeMode.dark,
                ThemeMode.system => AppThemeMode.system,
              };

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppThemeMode.values.map((mode) {
                  final label = switch (mode) {
                    AppThemeMode.system => 'Системная',
                    AppThemeMode.light => 'Светлая',
                    AppThemeMode.dark => 'Тёмная',
                  };
                  return CategoryChip(
                    label: label,
                    selected: current == mode,
                    onSelected: (_) =>
                        ref.read(themeModeProvider.notifier).setMode(mode),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionTitle(title: 'Уведомления'),
          if (profileAsync == null)
            ListItem(
              title: 'Push-уведомления',
              subtitle: 'Войдите, чтобы управлять уведомлениями',
              showChevron: false,
              leading: const Icon(Icons.notifications_outlined, size: 22),
              onTap: () => promptLogin(context, ref),
            )
          else
            profileAsync.when(
            loading: () => const ListItem(
              title: 'Загрузка…',
              showChevron: false,
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (profile) => AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Push-уведомления',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Сообщения, заказы и документы',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: profile.notificationsEnabled,
                    onChanged: (value) async {
                      await ref.read(profileActionsProvider).updateProfile(
                            notificationsEnabled: value,
                          );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
