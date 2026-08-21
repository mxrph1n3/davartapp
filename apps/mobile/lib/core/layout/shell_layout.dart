import 'package:flutter/material.dart';

/// Layout metrics for the bottom navigation shell.
abstract final class ShellLayout {
  /// Icon + label row.
  static const double navBarHeight = 52;
  static const double navTopPadding = 6;
  static const double navBottomInset = 2;

  static double bottomNavExtent(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return navBarHeight +
        navTopPadding +
        (bottomSafe > 0 ? bottomSafe : navBottomInset);
  }
}
