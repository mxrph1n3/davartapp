import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/tab_page.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../commerce/presentation/commerce_notifier.dart';
import 'shop_state.dart';

/// Colors of the shop tiles: (dark theme, light theme). Unknown slugs fall back to neutral.
const _tileColors = <String, (Color, Color)>{
  'vse': (Color(0xFF2A2A2A), Color(0xFFF2F1EC)),
  'napolnye-pokrytiya': (Color(0xFF3A2F22), Color(0xFFF3E9DC)),
  'plitka-i-keramogranit': (Color(0xFF2B3138), Color(0xFFECEFF2)),
  'santehnika': (Color(0xFF26323A), Color(0xFFE6EFF3)),
  'steny': (Color(0xFF2E2C26), Color(0xFFEFECE4)),
  'dveri': (Color(0xFF2A2D33), Color(0xFFECEEF1)),
  'svet-i-elektrika': (Color(0xFF3A3420), Color(0xFFF6EFD6)),
  'kondicionery-i-otoplenie': (Color(0xFF352826), Color(0xFFF3E6E3)),
  'mebel': (Color(0xFF36302A), Color(0xFFF2EBE2)),
  'korpusnaya-mebel': (Color(0xFF30291F), Color(0xFFF1E8DC)),
  'bytovaya-tehnika': (Color(0xFF2D2B27), Color(0xFFEEEBE5)),
  'dekor-i-tekstil': (Color(0xFF31302A), Color(0xFFEFEDE4)),
  'okna': (Color(0xFF26303A), Color(0xFFE9EEF3)),
  'potolki': (Color(0xFF2B2B30), Color(0xFFEFEFF3)),
};

/// Tall objects (doors, wardrobes, lamps) get more height in the tile.
const _tallImages = {'dveri', 'korpusnaya-mebel', 'svet-i-elektrika', 'okna'};

class ShopHomeScreen extends ConsumerStatefulWidget {
  const ShopHomeScreen({super.key});

  @override
  ConsumerState<ShopHomeScreen> createState() => _ShopHomeScreenState();
}

class _ShopHomeScreenState extends ConsumerState<ShopHomeScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration.zero, () {
      if (!mounted) return;
      final isStaff = ref.read(authProvider).user?.role.isStudio == true;
      if (!isStaff) ref.read(cartProvider.notifier).loadCart();
      ref.read(favoritesProvider.notifier).loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final role = ref.watch(authProvider).user?.role;
    final categories = ref.watch(shopCategoriesProvider);

    void open(String slug) => context.push(categoryPathForRole(role, slug));

    return TabPage(
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(shopCategoriesProvider.future),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Магазин',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Избранное',
                      onPressed: () => context.push(favoritesPathForRole(role)),
                      icon: const Icon(Icons.favorite_border, size: 26),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: GestureDetector(
                  onTap: () => context.push(searchPathForRole(role)),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: colors.textSecondary),
                        const SizedBox(width: 10),
                        Text('Поиск товаров', style: TextStyle(color: colors.textSecondary, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            categories.when(
              loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
              error: (_, _) => SliverFillRemaining(
                child: ErrorState(
                  message: 'Не удалось загрузить каталог',
                  onRetry: () => ref.invalidate(shopCategoriesProvider),
                ),
              ),
              data: (list) {
                final tiles = <({String slug, String name})>[
                  (slug: 'vse', name: 'Весь каталог'),
                  for (final c in list) (slug: c.slug, name: c.name),
                ];
                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(14, 0, 14, 24 + MediaQuery.paddingOf(context).bottom),
                  sliver: SliverGrid.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.92,
                    children: [
                      for (final t in tiles)
                        _CategoryTile(slug: t.slug, name: t.name, onTap: () => open(t.slug)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.slug, required this.name, required this.onTap});

  final String slug;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pair = _tileColors[slug] ?? (const Color(0xFF2A2A2A), const Color(0xFFF1F1EF));
    final tall = _tallImages.contains(slug);
    return Material(
      color: dark ? pair.$1 : pair.$2,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              right: -4,
              bottom: -4,
              width: tall ? 70 : 92,
              height: tall ? 92 : 72,
              child: Image.asset(
                'assets/catalog/$slug.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomRight,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 8, 0),
              child: _TileTitle(name, color: dark ? Colors.white : const Color(0xFF1A1A1A)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tile name without breaks inside a word: the font shrinks until the longest word fits.
class _TileTitle extends StatelessWidget {
  const _TileTitle(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final longest = text.split(' ').reduce((a, b) => a.length >= b.length ? a : b);
        var size = 12.5;
        final base = DefaultTextStyle.of(context).style;
        TextStyle style() =>
            base.merge(TextStyle(fontSize: size, height: 1.15, fontWeight: FontWeight.w700, color: color));
        while (size > 9) {
          final painter = TextPainter(
            text: TextSpan(text: longest, style: style()),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final fits = painter.width <= constraints.maxWidth;
          painter.dispose();
          if (fits) break;
          size -= 0.5;
        }
        return Text(text, style: style());
      },
    );
  }
}
