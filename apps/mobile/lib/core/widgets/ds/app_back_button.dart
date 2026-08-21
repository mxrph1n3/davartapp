import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../router/app_router.dart';

/// Always visible back control. Uses [popOrGo] so a screen opened with
/// `go` / deep link (empty stack) still has an exit.
class AppBackButton extends ConsumerWidget {
  const AppBackButton({
    super.key,
    required this.fallback,
    this.icon = Icons.arrow_back_ios_new,
    this.iconSize = 20,
  });

  final String fallback;
  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: Icon(icon, size: iconSize),
      onPressed: () => popOrGo(context, fallback),
    );
  }
}
