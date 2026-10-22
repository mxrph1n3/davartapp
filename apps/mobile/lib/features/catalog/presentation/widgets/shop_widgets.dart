import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../data/catalog_models.dart';
import 'shop_cart.dart';

/// Yellow on dark backgrounds; a deeper gold on light ones, where pure yellow is unreadable.
Color shopAccentLine(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppColors.of(context).accent
        : const Color(0xFFC9A400);

/// Yellow «+» / «−» drawn with round caps (same weight in both themes).
class AccentGlyph extends StatelessWidget {
  const AccentGlyph({required this.plus, this.size = 20});

  final bool plus;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(color: shopAccentLine(context), plus: plus),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter({required this.color, required this.plus});

  final Color color;
  final bool plus;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.1
      ..strokeCap = StrokeCap.round;
    final c = size.center(Offset.zero);
    final r = size.width * 0.3;
    canvas.drawLine(c.translate(-r, 0), c.translate(r, 0), p);
    if (plus) canvas.drawLine(c.translate(0, -r), c.translate(0, r), p);
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.color != color || old.plus != plus;
}

/// «+» before the product is in the cart; «− N +» with м² under N after.
class QtyCounter extends ConsumerWidget {
  const QtyCounter({super.key, required this.product, this.compact = true});

  final ProductSummary product;

  /// Compact — list rows; otherwise a wide counter for grid tiles.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final line = ShopCart.isStaff(ref) ? null : personalCartLine(ref, product.id);
    final qty = line?.quantity ?? 0;

    if (qty == 0) {
      if (compact) {
        return _TapArea(
          size: 44,
          onTap: () => ShopCart.add(context, ref, product),
          child: const AccentGlyph(plus: true, size: 28),
        );
      }
      return OutlinedButton(
        onPressed: () => ShopCart.add(context, ref, product),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(38),
          side: BorderSide(color: colors.border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          foregroundColor: colors.textPrimary,
        ),
        child: const Text('В корзину', style: TextStyle(fontWeight: FontWeight.w500)),
      );
    }

    final number = Text(
      qtyLabel(product, qty, withUnit: !compact),
      style: TextStyle(fontSize: compact ? 16 : 15, color: colors.textPrimary, height: 1.1),
    );
    final amount = product.sellByPack
        ? Text(
            amountLabel(product, qty),
            style: TextStyle(fontSize: 10.5, color: colors.textSecondary, height: 1.2),
          )
        : null;
    return SizedBox(
      width: compact ? null : double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
            children: [
              _TapArea(onTap: () => ShopCart.remove(context, ref, product), child: const AccentGlyph(plus: false)),
              SizedBox(width: compact ? 22 : 0, child: compact ? Center(child: number) : null),
              if (!compact) number,
              _TapArea(onTap: () => ShopCart.add(context, ref, product), child: const AccentGlyph(plus: true)),
            ],
          ),
          ?amount,
        ],
      ),
    );
  }
}

class _TapArea extends StatelessWidget {
  const _TapArea({required this.child, required this.onTap, this.size = 36});

  final Widget child;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: size / 2,
      child: SizedBox.square(dimension: size, child: Center(child: child)),
    );
  }
}

/// «3 450 ₽ / м²»
class UnitPrice extends StatelessWidget {
  const UnitPrice({super.key, required this.product, this.size = 15});

  final ProductSummary product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: formatPrice(product.price),
            style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: colors.textPrimary),
          ),
          TextSpan(
            text: ' / ${product.unit}',
            style: TextStyle(fontSize: size * 0.72, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Green «● в наличии» or amber «● срок 7–10 дней».
class StockLine extends StatelessWidget {
  const StockLine({super.key, required this.product, this.size = 11.5, this.long = false});

  final ProductSummary product;
  final double size;
  final bool long;

  @override
  Widget build(BuildContext context) {
    final inStock = product.inStock;
    final color = inStock ? const Color(0xFF3FBF73) : const Color(0xFFE0A64A);
    final text = inStock ? (long ? 'В наличии — доставка 2–3 дня' : 'в наличии') : product.leadTimeLabel;
    return Text('● $text', style: TextStyle(fontSize: size, color: color));
  }
}

String productSubtitle(ProductSummary product) {
  final parts = <String>[
    if (product.brand.name.isNotEmpty) product.brand.name,
    ...product.highlights.take(2),
    if (product.sellByPack && product.packSize != null)
      '${amountLabel(product, 1)} в уп.',
  ];
  return parts.join(' · ');
}

/// Compact list row: photo, name, brand · size · surface, price, stock, counter.
class ProductRow extends StatelessWidget {
  const ProductRow({super.key, required this.product, required this.onTap});

  final ProductSummary product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.divider))),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _Photo(url: product.imageUrl, size: 74),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.25, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    productSubtitle(product),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [UnitPrice(product: product), StockLine(product: product)],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            QtyCounter(product: product),
          ],
        ),
      ),
    );
  }
}

/// Grid tile, two per row.
class ProductGridTile extends StatelessWidget {
  const ProductGridTile({super.key, required this.product, required this.onTap});

  final ProductSummary product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(borderRadius: BorderRadius.circular(14), child: _Photo(url: product.imageUrl)),
          ),
          const SizedBox(height: 6),
          UnitPrice(product: product),
          const SizedBox(height: 2),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.25, color: colors.textPrimary),
          ),
          Text(
            productSubtitle(product),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: colors.textSecondary),
          ),
          const Spacer(),
          QtyCounter(product: product, compact: false),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.url, this.size});

  final String? url;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final placeholder = Container(width: size, height: size, color: colors.imagePlaceholder);
    if (url == null || url!.isEmpty) return placeholder;
    return Image.network(
      url!,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}
