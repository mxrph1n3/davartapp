import 'package:flutter/material.dart';

/// Unfocuses the active text field — use on tap outside inputs.
void dismissKeyboard([BuildContext? context]) {
  final focus = FocusManager.instance.primaryFocus;
  if (focus == null || !focus.hasFocus) return;
  focus.unfocus();
}

/// Taps outside the focused field hide the keyboard, including on empty
/// space inside a scroll view.
class DismissKeyboard extends StatelessWidget {
  const DismissKeyboard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        final focus = FocusManager.instance.primaryFocus;
        if (focus == null || !focus.hasFocus) return;
        final render = focus.context?.findRenderObject();
        if (render is RenderBox && render.attached && render.hasSize) {
          final topLeft = render.localToGlobal(Offset.zero);
          final rect = topLeft & render.size;
          if (rect.inflate(12).contains(event.position)) return;
        }
        focus.unfocus();
      },
      child: child,
    );
  }
}
