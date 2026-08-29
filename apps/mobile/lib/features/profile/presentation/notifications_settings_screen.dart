import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../auth/presentation/require_login.dart';
import 'notification_prefs_notifier.dart';

class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(authProvider).isAuthenticated;
    final prefsAsync = ref.watch(notificationPrefsProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppBackButton(
          fallback: profilePathForRole(ref.watch(authProvider).user?.role),
        ),
        title: const Text('Уведомления'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          if (!isAuthenticated)
            ListItem(
              title: 'Войдите',
              subtitle: 'Чтобы управлять уведомлениями',
              leading: const Icon(Icons.login, size: 22),
              onTap: () => promptLogin(context, ref),
            )
          else
            prefsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const ListItem(
                title: 'Не удалось загрузить',
                showChevron: false,
              ),
              data: (prefs) => Column(
                children: [
                  _NotificationToggle(
                    title: 'Сообщения',
                    subtitle: 'Чаты и ответы поддержки',
                    icon: Icons.chat_bubble_outline,
                    value: prefs.messages,
                    onChanged: (value) => ref
                        .read(notificationPrefsProvider.notifier)
                        .setMessages(value),
                  ),
                  _NotificationToggle(
                    title: 'Заказы',
                    subtitle: 'Статусы и доставка',
                    icon: Icons.shopping_bag_outlined,
                    value: prefs.orders,
                    onChanged: (value) => ref
                        .read(notificationPrefsProvider.notifier)
                        .setOrders(value),
                  ),
                  _NotificationToggle(
                    title: 'Документы',
                    subtitle: 'Файлы и согласования по проекту',
                    icon: Icons.description_outlined,
                    value: prefs.documents,
                    onChanged: (value) => ref
                        .read(notificationPrefsProvider.notifier)
                        .setDocuments(value),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationToggle extends StatelessWidget {
  const _NotificationToggle({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
