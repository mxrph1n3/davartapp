import 'package:flutter/material.dart';

/// Layout metrics for the bottom navigation shell.
abstract final class ShellLayout {
  /// Height of the floating glass capsule (icon + label).
  static const double navBarHeight = 62;
  static const double navTopPadding = 0;
  static const double navBottomInset = 2;
  static const double navSideInset = 14;
  static const double navFloatGap = 10;

  /// Space the capsule takes from the bottom of the screen.
  static double bottomNavExtent(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return navBarHeight + (bottomSafe > 0 ? bottomSafe - 8 : navFloatGap);
  }
}
