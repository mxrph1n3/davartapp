import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/ds/bottom_navigation.dart';
import '../../features/chat/presentation/chat_notifier.dart';
import '../../features/commerce/presentation/commerce_notifier.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration.zero, () {
      ref.read(cartProvider.notifier).loadCart();
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadAsync = ref.watch(unreadTotalProvider);
    final unreadTotal = unreadAsync.value ?? 0;
    final cartCount = ref.watch(cartProvider).itemCount;
    final currentIndex = widget.navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: widget.navigationShell,
      bottomNavigationBar: DavartBottomNavigation(
        currentIndex: currentIndex,
        onTap: (index) {
          // Always use goBranch inside StatefulShellRoute — context.go
          // can leave the shell stuck on one branch (e.g. cart).
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == currentIndex,
          );
        },
        items: [
          const DavartNavItem(
            icon: Icons.grid_view_outlined,
            selectedIcon: Icons.grid_view,
            label: 'Каталог',
          ),
          const DavartNavItem(
            icon: Icons.folder_outlined,
            selectedIcon: Icons.folder,
            label: 'Проекты',
          ),
          DavartNavItem(
            icon: Icons.chat_bubble_outline,
            selectedIcon: Icons.chat_bubble,
            label: 'Чаты',
            badge: unreadTotal > 0 ? unreadTotal : null,
          ),
          DavartNavItem(
            icon: Icons.shopping_bag_outlined,
            selectedIcon: Icons.shopping_bag,
            label: 'Корзина',
            badge: cartCount > 0 ? cartCount : null,
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
