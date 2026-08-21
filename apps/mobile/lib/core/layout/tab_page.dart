import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Root content for a bottom-tab screen. The shell [Scaffold] owns the frame.
///
/// Wraps content in [Material] so DS controls have the required ancestor.
/// [SizedBox.expand] keeps the tab inside shell body bounds so layouts cannot
/// overflow and steal taps from the bottom navigation.
class TabPage extends StatelessWidget {
  const TabPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: SizedBox.expand(child: child),
      ),
    );
  }
}
