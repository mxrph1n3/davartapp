import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class ProductGallery extends StatefulWidget {
  const ProductGallery({
    super.key,
    required this.imageUrls,
  });

  final List<String> imageUrls;

  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  var _page = 0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final urls = widget.imageUrls.where((u) => u.isNotEmpty).toList();

    if (urls.isEmpty) {
      return ColoredBox(
        color: colors.imagePlaceholder,
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 48,
            color: colors.textSecondary,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: urls.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, index) => Image.network(
            urls[index],
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => ColoredBox(
              color: colors.imagePlaceholder,
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
        if (urls.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(urls.length, (i) {
                final active = i == _page;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? colors.textPrimary
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
