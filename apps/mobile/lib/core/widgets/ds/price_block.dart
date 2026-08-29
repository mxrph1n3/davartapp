import 'package:flutter/material.dart';
import '../../utils/price_formatter.dart';

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
    final textTheme = Theme.of(context).textTheme;
    final mainStyle = switch (size) {
      PriceSize.large => textTheme.headlineMedium,
      PriceSize.medium => textTheme.titleLarge,
      PriceSize.small => textTheme.titleMedium,
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
            style: textTheme.bodySmall?.copyWith(
                  decoration: TextDecoration.lineThrough,
                ),
          ),
        ],
      ],
    );
  }
}

enum PriceSize { large, medium, small }
