import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool expand;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final child = AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      child: Material(
        color: widget.onPressed == null && !widget.isLoading
            ? colors.accent.withValues(alpha: 0.4)
            : (_pressed ? colors.accentPressed : colors.accent),
        borderRadius: AppRadius.buttonRadius,
        child: InkWell(
          onTap: widget.isLoading ? null : widget.onPressed,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          borderRadius: AppRadius.buttonRadius,
          child: SizedBox(
            height: 54,
            width: widget.expand ? double.infinity : null,
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.textOnAccent,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        widget.label,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );

    return widget.expand ? child : child;
  }
}
