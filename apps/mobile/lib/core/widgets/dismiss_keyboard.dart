import 'package:flutter/material.dart';

/// Unfocuses the active text field — use on tap outside inputs.
void dismissKeyboard([BuildContext? context]) {
  final focus = FocusManager.instance.primaryFocus;
  if (focus == null || !focus.hasFocus) return;
  focus.unfocus();
}

/// Wraps the app shell so taps on empty space hide the keyboard.
class DismissKeyboard extends StatelessWidget {
  const DismissKeyboard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => dismissKeyboard(context),
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}
