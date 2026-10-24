import 'dart:ui' show ImageFilter;

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
    final colors = AppColors.of(context);
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    // Liquid Glass: a floating translucent capsule; content scrolls under it, blurred.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accentText = colors.accentText;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ShellLayout.navSideInset,
        0,
        ShellLayout.navSideInset,
        bottomSafe > 0 ? bottomSafe - 8 : ShellLayout.navFloatGap,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ShellLayout.navBarHeight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.45 : 0.16),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ShellLayout.navBarHeight),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: ShellLayout.navBarHeight,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ShellLayout.navBarHeight),
                color: dark ? const Color(0x73282828) : const Color(0x8CFFFFFF),
                border: Border.all(
                  color: dark ? const Color(0x24FFFFFF) : const Color(0xB3FFFFFF),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? const [Color(0x1FFFFFFF), Color(0x00FFFFFF)]
                      : const [Color(0x66FFFFFF), Color(0x00FFFFFF)],
                  stops: const [0, 0.5],
                ),
              ),
              child: Row(
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final selected = index == currentIndex;
                  final color = selected ? accentText : (dark ? const Color(0xFFD8D8D8) : const Color(0xFF333333));

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(ShellLayout.navBarHeight),
                          color: selected
                              ? (dark ? const Color(0x1AFFFFFF) : const Color(0x0F000000))
                              : Colors.transparent,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                item.iconBuilder != null
                                    ? item.iconBuilder!(color, selected)
                                    : Icon(selected ? item.selectedIcon : item.icon, size: 24, color: color),
                                if (item.badge != null && item.badge! > 0)
                                  Positioned(
                                    right: -10,
                                    top: -6,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                      child: Text(
                                        item.badge! > 9 ? '9+' : '${item.badge}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: colors.textOnAccent,
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
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                color: color,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DavartNavItem {
  const DavartNavItem({
    this.icon = Icons.circle_outlined,
    this.selectedIcon = Icons.circle,
    this.iconBuilder,
    this.label,
    this.badge,
  });

  final IconData icon;
  final IconData selectedIcon;
  final Widget Function(Color color, bool selected)? iconBuilder;
  final String? label;
  final int? badge;
}
