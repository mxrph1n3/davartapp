import 'package:flutter/material.dart';
import '../../utils/price_formatter.dart';
import '../../theme/app_typography.dart';

class PriceBlock extends StatelessWidget {
  const PriceBlock({
    super.key,
    required this.price,
    this.compareAtPrice,
    this.size = PriceSize.medium,
  });

  final double price;
  final double? compareAtPrice;
  final PriceSize size;

  @override
  Widget build(BuildContext context) {
    final mainStyle = switch (size) {
      PriceSize.large => AppTypography.textTheme.headlineMedium,
      PriceSize.medium => AppTypography.textTheme.titleLarge,
      PriceSize.small => AppTypography.textTheme.titleMedium,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatPrice(price),
          style: mainStyle?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (compareAtPrice != null) ...[
          const SizedBox(width: 8),
          Text(
            formatPrice(compareAtPrice!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  decoration: TextDecoration.lineThrough,
                ),
          ),
        ],
      ],
    );
  }
}

enum PriceSize { large, medium, small }
