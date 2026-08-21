import 'package:flutter/material.dart';

import '../../utils/price_formatter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'quantity_stepper.dart' show AddButton;

/// Yandex Market–style row: image left, copy + price right.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    this.brand,
    this.description,
    this.imageUrl,
    this.inStock = true,
    this.isFavorite = false,
    required this.onTap,
    this.onAddToCart,
    this.onFavoriteToggle,
  });

  final String name;
  final double price;
  final String? brand;
  final String? description;
  final String? imageUrl;
  final bool inStock;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;
  final VoidCallback? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final showBrand = brand != null &&
        brand!.isNotEmpty &&
        !_isRedundantBrand(name, brand!);
    final desc = description?.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: 112,
              height: 112,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.imageRadius,
                    child: ColoredBox(
                      color: AppColors.imagePlaceholder,
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _placeholder(),
                            )
                          : _placeholder(),
                    ),
                  ),
                  if (!inStock)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withValues(alpha: 0.7),
                          borderRadius: AppRadius.pillRadius,
                        ),
                        child: const Text(
                          'Нет в наличии',
                          style: TextStyle(
                            color: AppColors.background,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onTap,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                height: 1.25,
                              ),
                            ),
                          ),
                          if (onFavoriteToggle != null)
                            _HeartButton(
                              selected: isFavorite,
                              onPressed: onFavoriteToggle!,
                            ),
                        ],
                      ),
                      if (showBrand) ...[
                        const SizedBox(height: 2),
                        Text(
                          brand!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (desc != null && desc.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        formatPrice(price),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onAddToCart != null) ...[
                  const SizedBox(height: 8),
                  AddButton(onPressed: onAddToCart),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return const Center(
      child: Icon(Icons.image_outlined, color: AppColors.textSecondary),
    );
  }
}

bool _isRedundantBrand(String name, String brand) {
  final normalizedName = name.toLowerCase();
  final normalizedBrand = brand.toLowerCase();
  return normalizedName == normalizedBrand ||
      normalizedName.startsWith('$normalizedBrand ');
}

class _HeartButton extends StatelessWidget {
  const _HeartButton({required this.selected, required this.onPressed});

  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            selected ? Icons.favorite : Icons.favorite_border,
            size: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
