import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

OverlayEntry? _current;
Timer? _timer;

/// Short notice at the top of the screen, under the status bar.
///
/// Used instead of a SnackBar where the bottom of the screen holds the main
/// action (cart buttons, the bottom bar) and a SnackBar would cover it.
void showTopNotice(BuildContext? context, String message) {
  if (context == null || !context.mounted) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _timer?.cancel();
  _current?.remove();
  final colors = AppColors.of(context);
  final entry = OverlayEntry(
    builder: (ctx) => Positioned(
      top: MediaQuery.of(ctx).padding.top + 8,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6)),
              ],
            ),
            child: Text(
              message,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  _current = entry;
  _timer = Timer(const Duration(seconds: 2), () {
    if (_current == entry) {
      entry.remove();
      _current = null;
    }
  });
}
