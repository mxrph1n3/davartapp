import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/settings/settings_notifier.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../auth/presentation/require_login.dart';

/// Legacy route — settings live on the profile tab now.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = profilePathForRole(ref.watch(authProvider).user?.role);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go(path);
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class ProfileAccountSection extends ConsumerWidget {
  const ProfileAccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListItem(
      title: 'Личные данные',
      leading: const Icon(Icons.person_outline, size: 22),
      onTap: () async {
        if (!await promptLogin(context, ref)) return;
        if (context.mounted) {
          context.push(
            editProfilePathForRole(ref.read(authProvider).user?.role),
          );
        }
      },
    );
  }
}

class ProfileThemeSection extends ConsumerWidget {
  const ProfileThemeSection({super.key});

  static String _label(AppThemeMode mode) => switch (mode) {
        AppThemeMode.system => 'Системная',
        AppThemeMode.light => 'Светлая',
        AppThemeMode.dark => 'Тёмная',
      };

  static AppThemeMode _fromThemeMode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => AppThemeMode.light,
        ThemeMode.dark => AppThemeMode.dark,
        ThemeMode.system => AppThemeMode.system,
      };

  Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref,
    AppThemeMode current,
  ) async {
    final selected = await showCupertinoModalPopup<AppThemeMode>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Тема'),
        actions: [
          for (final mode in const [
            AppThemeMode.system,
            AppThemeMode.dark,
            AppThemeMode.light,
          ])
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(mode),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_label(mode)),
                  if (mode == current) ...[
                    const SizedBox(width: 8),
                    const Icon(CupertinoIcons.check_mark, size: 18),
                  ],
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (selected != null) {
      await ref.read(themeModeProvider.notifier).setMode(selected);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeAsync = ref.watch(themeModeProvider);

    return themeModeAsync.when(
      loading: () => const ListItem(
        title: 'Тема',
        leading: Icon(CupertinoIcons.circle_lefthalf_fill, size: 22),
        showChevron: false,
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (themeMode) {
        final current = _fromThemeMode(themeMode);
        return ListItem(
          title: 'Тема',
          leading: const Icon(CupertinoIcons.circle_lefthalf_fill, size: 22),
          onTap: () => _pickTheme(context, ref, current),
        );
      },
    );
  }
}

class ProfileNotificationsSection extends ConsumerWidget {
  const ProfileNotificationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListItem(
      title: 'Уведомления',
      leading: const Icon(Icons.notifications_outlined, size: 22),
      onTap: () async {
        if (!await promptLogin(context, ref)) return;
        if (context.mounted) {
          context.push(
            notificationsPathForRole(ref.read(authProvider).user?.role),
          );
        }
      },
    );
  }
}
