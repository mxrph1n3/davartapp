import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';

/// Flattened catalog CTA — wide hit target, low height (not a round +).
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  static const double _height = 36;
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: enabled
          ? AppColors.accent
          : AppColors.accent.withValues(alpha: 0.4),
      borderRadius: _radius,
      child: InkWell(
        onTap: onPressed,
        borderRadius: _radius,
        child: const SizedBox(
          height: _height,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_shopping_cart_outlined,
                  size: 16,
                  color: AppColors.textOnAccent,
                ),
                SizedBox(width: 6),
                Text(
                  'В корзину',
                  style: TextStyle(
                    color: AppColors.textOnAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.buttonRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Btn(icon: Icons.remove, onPressed: onDecrement),
          SizedBox(
            width: 36,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          _Btn(icon: Icons.add, onPressed: onIncrement),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.buttonRadius,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 18,
            color: onPressed == null
                ? AppColors.textDisabled
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
