import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/ds/bottom_navigation.dart';
import '../../features/chat/presentation/chat_notifier.dart';
import '../../features/staff/presentation/working_client_banner.dart';

class StaffShell extends ConsumerWidget {
  const StaffShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadTotalProvider);
    final unreadTotal = unreadAsync.value ?? 0;
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WorkingClientBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: DavartBottomNavigation(
        currentIndex: currentIndex,
        onTap: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == currentIndex,
          );
        },
        items: [
          DavartNavItem(
            icon: Icons.chat_bubble_outline,
            selectedIcon: Icons.chat_bubble,
            label: 'Чаты',
            badge: unreadTotal > 0 ? unreadTotal : null,
          ),
          const DavartNavItem(
            icon: Icons.people_outline,
            selectedIcon: Icons.people,
            label: 'Клиенты',
          ),
          const DavartNavItem(
            icon: Icons.grid_view_outlined,
            selectedIcon: Icons.grid_view,
            label: 'Каталог',
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
