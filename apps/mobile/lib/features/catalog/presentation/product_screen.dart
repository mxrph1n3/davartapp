import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/top_notice.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../auth/presentation/require_login.dart';
import '../../commerce/presentation/commerce_notifier.dart';
import '../data/catalog_models.dart';
import 'catalog_notifier.dart';
import 'widgets/shop_cart.dart';
import 'widgets/shop_widgets.dart';

/// Reserve for cutting, added by the area calculator.
const _reserve = 0.15;

/// Whole packs to cover [area] (with the 15 % reserve if [withReserve]); null for bad input.
int? packsForArea(double? area, double? packSize, {bool withReserve = true}) {
  if (area == null || area <= 0 || packSize == null || packSize <= 0) return null;
  final need = withReserve ? area * (1 + _reserve) : area;
  return (need / packSize - 1e-9).ceil();
}

/// Product card v3: gallery, price per unit and per pack, area calculator,
/// specs, collection, similar; bottom bar «− N уп. +» and the cart button with the sum.
class ProductScreen extends ConsumerStatefulWidget {
  const ProductScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends ConsumerState<ProductScreen> {
  int? _packs;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration.zero, () {
      if (!mounted) return;
      ref.read(favoritesProvider.notifier).loadFavorites();
      if (!ShopCart.isStaff(ref)) ref.read(cartProvider.notifier).loadCart();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final role = ref.watch(authProvider).user?.role;
    final home = catalogPathForRole(role);
    final async = ref.watch(productDetailProvider(widget.productId));

    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(leading: AppBackButton(fallback: home)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(leading: AppBackButton(fallback: home)),
        body: ErrorState(
          message: 'Не удалось загрузить товар',
          onRetry: () => ref.invalidate(productDetailProvider(widget.productId)),
        ),
      ),
      data: (product) {
        final staff = ShopCart.isStaff(ref);
        final line = staff ? null : personalCartLine(ref, product.id);
        final packs = _packs ?? line?.quantity ?? 1;
        final isFavorite = ref.watch(favoritesProvider).isFavorite(product.id);
        final images = [
          ...product.images,
          if (product.images.isEmpty && (product.imageUrl ?? '').isNotEmpty) product.imageUrl!,
        ];
        final meta = [
          if (product.brand.name.isNotEmpty) product.brand.name,
          if (product.sku.isNotEmpty) 'арт. ${product.sku}',
        ].join(' · ');

        return Scaffold(
          backgroundColor: colors.background,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Gallery(
                  images: images,
                  topBar: Row(
                    children: [
                      _RoundIcon(
                        icon: Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        onTap: () => popOrGo(context, home),
                      ),
                      const Spacer(),
                      _RoundIcon(
                        icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFavorite ? const Color(0xFFE5484D) : null,
                        onTap: () => _toggleFavorite(product.id),
                      ),
                      const SizedBox(width: 8),
                      _RoundIcon(icon: Icons.ios_share_rounded, onTap: () => _share(product)),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                sliver: SliverList.list(
                  children: [
                    if (meta.isNotEmpty)
                      Text(meta, style: TextStyle(fontSize: 12.5, color: colors.textSecondary, letterSpacing: 0.2)),
                    const SizedBox(height: 4),
                    Text(
                      product.name,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.2, color: colors.textPrimary),
                    ),
                    if (product.highlights.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [for (final h in product.highlights) _InfoChip(text: h)],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        UnitPrice(product: product, size: 24),
                        if (product.sellByPack && product.packSize != null) ...[
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              '${formatPrice(product.cartUnitPrice)} за уп. (${amountLabel(product, 1)})',
                              style: TextStyle(fontSize: 13, color: colors.textSecondary),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    StockLine(product: product, size: 13.5, long: true),
                    const SizedBox(height: 6),
                    Text(
                      'Цену и наличие подтвердит менеджер после оформления',
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                    if (product.sellByPack && product.packSize != null) ...[
                      const SizedBox(height: 18),
                      _AreaCalculator(
                        product: product,
                        onApply: (n) => setState(() => _packs = n),
                      ),
                    ],
                    if (product.attributes.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _SectionTitle('Характеристики'),
                      for (final a in product.attributes) _SpecRow(label: a.key, value: a.value),
                      if (product.packPieces != null)
                        _SpecRow(label: 'Штук в упаковке', value: '${product.packPieces}'),
                      if (product.sellByPack && product.packSize != null)
                        _SpecRow(label: 'В упаковке', value: amountLabel(product, 1)),
                    ],
                    if ((product.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _SectionTitle('Описание'),
                      Text(
                        product.description!.trim(),
                        style: TextStyle(fontSize: 14.5, height: 1.45, color: colors.textPrimary.withValues(alpha: 0.8)),
                      ),
                    ],
                  ],
                ),
              ),
              if (product.collection.isNotEmpty) ...[
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(18, 26, 18, 0), child: _SectionTitle('Из этой коллекции'))),
                SliverToBoxAdapter(child: _ProductStrip(products: product.collection)),
              ],
              if (product.similar.isNotEmpty) ...[
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(18, 26, 18, 0), child: _SectionTitle('Похожие'))),
                SliverToBoxAdapter(child: _ProductStrip(products: product.similar)),
              ],
              SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom)),
            ],
          ),
          bottomNavigationBar: _BottomBar(
            product: product,
            packs: packs,
            inCart: line?.quantity,
            staff: staff,
            onPacks: (n) => setState(() => _packs = n),
            onCart: () => _toCart(product, packs, line?.id, line?.quantity),
          ),
        );
      },
    );
  }

  Future<void> _toCart(ProductDetail product, int packs, String? lineId, int? inCart) async {
    if (ShopCart.isStaff(ref)) {
      await ShopCart.add(context, ref, product, packs: packs);
      return;
    }
    if (inCart == packs) {
      context.go(AppRoutes.cart);
      return;
    }
    if (lineId == null) {
      await ShopCart.add(context, ref, product, packs: packs);
    } else {
      try {
        await ref.read(cartProvider.notifier).updateQuantity(lineId, packs);
      } catch (_) {
        if (mounted) showTopNotice(context, 'Не удалось изменить количество');
        return;
      }
    }
    if (mounted && personalCartLine(ref, product.id) != null) {
      showTopNotice(context, 'В корзине: ${qtyLabel(product, packs, withUnit: true)}');
    }
  }

  Future<void> _toggleFavorite(String id) async {
    try {
      await toggleFavoriteWithLogin(context, ref, id);
    } catch (_) {
      if (mounted) showTopNotice(context, 'Не удалось обновить избранное');
    }
  }

  Future<void> _share(ProductDetail product) async {
    await Clipboard.setData(ClipboardData(text: '${product.name} — ${formatPrice(product.price)} / ${product.unit}'));
    if (mounted) showTopNotice(context, 'Скопировано');
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.images, required this.topBar});

  final List<String> images;
  final Widget topBar;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _pages = PageController();
  var _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final images = widget.images;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (images.isEmpty)
                ColoredBox(color: colors.imagePlaceholder)
              else
                PageView.builder(
                  controller: _pages,
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => Image.network(
                    images[i],
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(color: colors.imagePlaceholder),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(padding: const EdgeInsets.fromLTRB(14, 6, 14, 0), child: widget.topBar),
                ),
              ),
            ],
          ),
        ),
        if (images.length > 1)
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _pages.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                child: Container(
                  width: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: i == _index ? shopAccentLine(context) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      images[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(color: colors.imagePlaceholder),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap, this.size = 20, this.color});

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: colors.background.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 42,
          child: Icon(icon, size: size, color: color ?? colors.textPrimary),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: colors.surfaceMuted, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 12.5, color: colors.textPrimary)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.of(context).textPrimary),
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
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.divider))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: colors.textSecondary))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// «Сколько нужно»: area → packs, with a 15 % reserve that blinks to draw attention.
class _AreaCalculator extends StatefulWidget {
  const _AreaCalculator({required this.product, required this.onApply});

  final ProductSummary product;
  final ValueChanged<int> onApply;

  @override
  State<_AreaCalculator> createState() => _AreaCalculatorState();
}

class _AreaCalculatorState extends State<_AreaCalculator> with SingleTickerProviderStateMixin {
  final _area = TextEditingController();
  var _withReserve = true;
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _blink.repeat(reverse: true, count: 3);
  }

  @override
  void dispose() {
    _area.dispose();
    _blink.dispose();
    super.dispose();
  }

  double? get _value => double.tryParse(_area.text.replaceAll(',', '.').trim());

  int? get _packs => packsForArea(_value, widget.product.packSize, withReserve: _withReserve);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = shopAccentLine(context);
    final p = widget.product;
    final packs = _packs;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Сколько нужно', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textPrimary)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: _blink,
                  builder: (context, child) => DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color.lerp(colors.border, accent, _blink.value) ?? accent,
                        width: 1.5,
                      ),
                    ),
                    child: child,
                  ),
                  child: TextField(
                    controller: _area,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Площадь',
                      suffixText: p.unit,
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => setState(() => _withReserve = !_withReserve),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _withReserve ? accent.withValues(alpha: 0.16) : null,
                    border: Border.all(color: _withReserve ? accent : colors.border, width: 1.5),
                  ),
                  child: Text(
                    '+15 % запас',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _withReserve ? colors.textPrimary : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Запас на подрезку и бой. Плитку из разных партий сложно подобрать в тон — лучше взять сразу.',
            style: TextStyle(fontSize: 11.5, height: 1.3, color: colors.textSecondary),
          ),
          if (packs != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${qtyLabel(p, packs, withUnit: true)} ',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary),
                        ),
                        TextSpan(
                          text: '= ${amountLabel(p, packs)} · ${formatPrice(p.cartUnitPrice * packs)}',
                          style: TextStyle(fontSize: 13, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    widget.onApply(packs);
                  },
                  child: Text('Взять', style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductStrip extends ConsumerWidget {
  const _ProductStrip({required this.products});

  final List<ProductSummary> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).user?.role;
    return SizedBox(
      height: 300,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(
          width: 150,
          child: ProductGridTile(
            product: products[i],
            onTap: () => context.push(productPathForRole(role, products[i].id)),
          ),
        ),
      ),
    );
  }
}

/// «− 2 уп. +» with м² under it, and the cart button with the sum.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.product,
    required this.packs,
    required this.inCart,
    required this.staff,
    required this.onPacks,
    required this.onCart,
  });

  final ProductSummary product;
  final int packs;
  final int? inCart;
  final bool staff;
  final ValueChanged<int> onPacks;
  final VoidCallback onCart;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = shopAccentLine(context);
    final synced = inCart != null && inCart == packs;
    final sum = formatPrice(product.cartUnitPrice * packs);

    Widget step(bool plus, VoidCallback? onTap) => InkResponse(
          onTap: onTap,
          radius: 22,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(plus ? Icons.add : Icons.remove, color: onTap == null ? colors.border : accent, size: 24),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  height: 58,
                  decoration: BoxDecoration(color: colors.surfaceMuted, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      step(false, packs > 1 ? () => onPacks(packs - 1) : null),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              qtyLabel(product, packs, withUnit: true),
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.textPrimary),
                            ),
                            if (product.sellByPack && product.packSize != null)
                              Text(amountLabel(product, packs), style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
                          ],
                        ),
                      ),
                      step(true, () => onPacks(packs + 1)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: Material(
                  color: colors.surfaceMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: accent, width: 1.5),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onCart,
                    child: SizedBox(
                      height: 58,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            synced ? Icons.shopping_bag : Icons.shopping_bag_outlined,
                            size: 22,
                            color: colors.textPrimary,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sum,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary),
                                ),
                                Text(
                                  staff ? 'в корзину проекта' : (synced ? 'в корзине' : (inCart != null ? 'обновить' : 'в корзину')),
                                  style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
