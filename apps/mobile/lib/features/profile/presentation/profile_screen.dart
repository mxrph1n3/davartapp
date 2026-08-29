import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/tab_page.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../auth/presentation/require_login.dart';
import '../data/profile_repository.dart';
import 'profile_notifier.dart';
import 'settings_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    if (!authState.isAuthenticated) {
      return const _GuestProfile();
    }

    final profileAsync = ref.watch(profileProvider);
    final phone = authState.user?.phone ?? '—';
    final name = profileAsync.value?.name ?? authState.user?.name;
    final email = profileAsync.value?.email;

    return TabPage(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const ScreenHeader(title: 'Профиль'),
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
                        name ?? 'Пользователь',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email ?? phone,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const ProfileAccountSection(),
          ListItem(
            title: 'Заказы',
            leading: const Icon(Icons.shopping_bag_outlined, size: 22),
            onTap: () => context.push(AppRoutes.orders),
          ),
          ListItem(
            title: 'Избранное',
            leading: const Icon(Icons.favorite_border, size: 22),
            onTap: () => context.push(
              favoritesPathForRole(ref.read(authProvider).user?.role),
            ),
          ),
          ListItem(
            title: 'Поддержка',
            leading: const Icon(Icons.chat_bubble_outline, size: 22),
            onTap: () async {
              try {
                final chat =
                    await ref.read(profileRepositoryProvider).getSupportChat();
                if (context.mounted) {
                  context.push(
                    '${AppRoutes.chatDetail(chat.id)}?title=${Uri.encodeComponent(chat.title)}',
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Не удалось открыть чат')),
                  );
                }
              }
            },
          ),
          const ProfileThemeSection(),
          const ProfileNotificationsSection(),
          const SizedBox(height: AppSpacing.xl),
          SecondaryButton(
            label: 'Выйти',
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) context.go(AppRoutes.catalog);
            },
          ),
        ],
      ),
    );
  }
}

class _GuestProfile extends ConsumerWidget {
  const _GuestProfile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TabPage(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const ScreenHeader(title: 'Профиль'),
          Text(
            'Войдите по номеру',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Заказы, проекты и избранное появятся после входа',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Войти',
            onPressed: () => promptLogin(context, ref),
          ),
          const SizedBox(height: AppSpacing.xl),
          const ProfileThemeSection(),
          const ProfileNotificationsSection(),
          ListItem(
            title: 'Вопросы и ответы',
            leading: const Icon(Icons.help_outline, size: 22),
            onTap: () => context.push(AppRoutes.faq),
          ),
          ListItem(
            title: 'Конфиденциальность',
            leading: const Icon(Icons.privacy_tip_outlined, size: 22),
            onTap: () => context.push(AppRoutes.privacy),
          ),
          ListItem(
            title: 'Условия использования',
            leading: const Icon(Icons.description_outlined, size: 22),
            onTap: () => context.push(AppRoutes.terms),
          ),
        ],
      ),
    );
  }
}
