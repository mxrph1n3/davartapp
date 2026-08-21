import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../auth/presentation/require_login.dart';
import '../../commerce/presentation/commerce_notifier.dart';
import '../../staff/presentation/staff_cart_actions.dart';
import '../data/catalog_models.dart';
import 'catalog_notifier.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  var _showAllSpecs = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration.zero, () {
      ref.read(favoritesProvider.notifier).loadFavorites();
      ref.read(cartProvider.notifier).loadCart();
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalogHome = catalogPathForRole(ref.watch(authProvider).user?.role);
    final productAsync = ref.watch(productDetailProvider(widget.productId));
    final favorites = ref.watch(favoritesProvider);
    final textTheme = Theme.of(context).textTheme;

    return productAsync.when(
        loading: () => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: AppBackButton(fallback: catalogHome),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: AppBackButton(fallback: catalogHome),
          ),
          body: ErrorState(
            message: 'Не удалось загрузить товар',
            onRetry: () =>
                ref.invalidate(productDetailProvider(widget.productId)),
          ),
        ),
        data: (product) {
          final isFavorite = favorites.isFavorite(product.id);
          final images = [
            if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
              product.imageUrl!,
          ];
          final specs = _sortedSpecs(product.attributes);
          final visibleSpecs =
              _showAllSpecs ? specs : specs.take(3).toList(growable: false);

          return Scaffold(
            backgroundColor: AppColors.background,
            body: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.sizeOf(context).height * 0.52,
                child: ProductGallery(imageUrls: images),
              ),
              DraggableScrollableSheet(
                initialChildSize: 0.50,
                minChildSize: 0.50,
                maxChildSize: 0.92,
                builder: (context, scrollController) {
                  return DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius: AppRadius.sheetRadius,
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.screenPadding,
                        AppSpacing.sm,
                        AppSpacing.screenPadding,
                        100 + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        const Center(child: _SheetHandle()),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          product.name,
                          style: textTheme.headlineMedium?.copyWith(
                            fontSize: 26,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          product.brand.name.toUpperCase(),
                          style: textTheme.bodySmall?.copyWith(
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        PriceBlock(
                          price: product.price,
                          size: PriceSize.large,
                        ),
                        if (!product.inStock) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Нет в наличии',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (specs.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xl),
                          const SectionTitle(title: 'Характеристики'),
                          ...visibleSpecs.map(
                            (s) => _SpecRow(label: s.key, value: s.value),
                          ),
                          if (specs.length > 3) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GhostButton(
                                label: _showAllSpecs
                                    ? 'Скрыть'
                                    : 'Все характеристики',
                                onPressed: () => setState(
                                  () => _showAllSpecs = !_showAllSpecs,
                                ),
                              ),
                            ),
                          ],
                        ],
                        if (product.description != null &&
                            product.description!.trim().isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xl),
                          const SectionTitle(title: 'Описание'),
                          Text(
                            product.description!,
                            style: textTheme.bodyLarge?.copyWith(
                              color: AppColors.textPrimary
                                  .withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    0,
                  ),
                  child: Row(
                    children: [
                      _OverlayIcon(
                        icon: Icons.arrow_back_ios_new_rounded,
                        iconSize: 16,
                        onTap: () => popOrGo(context, catalogHome),
                      ),
                      const Spacer(),
                      _OverlayIcon(
                        icon: isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        onTap: () => _toggleFavorite(product.id),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _OverlayIcon(
                        icon: Icons.ios_share_rounded,
                        onTap: () => _share(product),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: BottomActionBar(
                  children: [
                    IconActionButton(
                      icon: isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      selected: isFavorite,
                      onPressed: () => _toggleFavorite(product.id),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    BottomActionBarButton(
                      label: 'В корзину',
                      onPressed: () => _addToCart(product.id),
                    ),
                  ],
                ),
              ),
            ],
          ),
          );
        },
    );
  }

  Future<void> _toggleFavorite(String id) async {
    try {
      await toggleFavoriteWithLogin(context, ref, id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось обновить избранное')),
      );
    }
  }

  Future<void> _addToCart(String id) async {
    await addProductToActiveCart(ref, id, context: context);
  }

  Future<void> _share(ProductDetail product) async {
    await Clipboard.setData(
      ClipboardData(text: '${product.name} — ${formatPrice(product.price)}'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Скопировано')),
    );
  }

  List<ProductAttribute> _sortedSpecs(List<ProductAttribute> attrs) {
    const order = ['Материал', 'Размеры', 'Цвет', 'Стиль'];
    final copy = [...attrs];
    copy.sort((a, b) {
      final ai = order.indexOf(a.key);
      final bi = order.indexOf(b.key);
      return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
    });
    return copy;
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillRadius,
      ),
    );
  }
}

/// Circular control over the hero — border depth, no elevation (DS depth).
class _OverlayIcon extends StatelessWidget {
  const _OverlayIcon({
    required this.icon,
    required this.onTap,
    this.iconSize = 20,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: iconSize, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: textTheme.bodyMedium),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
