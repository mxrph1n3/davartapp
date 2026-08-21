import 'package:flutter/material.dart';

import '../../layout/shell_layout.dart';
import '../../theme/app_colors.dart';

class DavartBottomNavigation extends StatelessWidget {
  const DavartBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<DavartNavItem> items;

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: AppColors.surface,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            top: ShellLayout.navTopPadding,
            bottom: bottomSafe > 0 ? bottomSafe : ShellLayout.navBottomInset,
          ),
          child: SizedBox(
            height: ShellLayout.navBarHeight,
            child: Row(
              children: List.generate(items.length, (index) {
                final item = items[index];
                final selected = index == currentIndex;
                final color = selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary;

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              selected ? item.selectedIcon : item.icon,
                              size: 24,
                              color: color,
                            ),
                            if (item.badge != null && item.badge! > 0)
                              Positioned(
                                right: -10,
                                top: -6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    item.badge! > 9 ? '9+' : '${item.badge}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: color,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class DavartNavItem {
  const DavartNavItem({
    required this.icon,
    required this.selectedIcon,
    this.label,
    this.badge,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String? label;
  final int? badge;
}
