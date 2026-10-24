import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/ds/bottom_navigation.dart';
import '../../features/auth/presentation/auth_notifier.dart';
import '../../features/chat/presentation/chat_notifier.dart';

class StaffShell extends ConsumerWidget {
  const StaffShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadTotalProvider);
    final unreadTotal = unreadAsync.value ?? 0;
    final canSeeClients = ref.watch(authProvider).user?.canSeeClients ?? false;
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      // Content scrolls under the floating glass bar.
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: navigationShell,
      bottomNavigationBar: DavartBottomNavigation(
        currentIndex: currentIndex,
        onTap: (index) {
          FocusManager.instance.primaryFocus?.unfocus();
          navigationShell.goBranch(
            index,
            initialLocation: index == currentIndex,
          );
        },
        items: [
          DavartNavItem(
            icon: Icons.send_outlined,
            selectedIcon: Icons.send,
            label: 'Чаты',
            badge: unreadTotal > 0 ? unreadTotal : null,
          ),
          DavartNavItem(
            icon: canSeeClients ? Icons.people_outline : Icons.folder_outlined,
            selectedIcon: canSeeClients ? Icons.people : Icons.folder,
            label: canSeeClients ? 'Клиенты' : 'Проекты',
          ),
          const DavartNavItem(
            icon: Icons.grid_view_outlined,
            selectedIcon: Icons.grid_view,
            label: 'Магазин',
          ),
          const DavartNavItem(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
