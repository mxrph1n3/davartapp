import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../data/portfolio_repository.dart';
import 'portfolio_widgets.dart';

final portfolioTilesProvider = FutureProvider.autoDispose<PortfolioTiles>((ref) {
  return ref.watch(portfolioRepositoryProvider).tiles();
});

/// Portfolio home: «Все проекты» collage, interior styles 3 per row, then Архитектура /
/// Экстерьер / Ландшафт. No project counts on tiles (decision of 22.10).
class PortfolioHomeScreen extends ConsumerWidget {
  const PortfolioHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final tiles = ref.watch(portfolioTilesProvider);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppBackButton(fallback: AppRoutes.projects),
        title: const Text('Портфолио'),
      ),
      body: tiles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить портфолио',
          onRetry: () => ref.invalidate(portfolioTilesProvider),
        ),
        data: (data) {
          void open({String? style, String? kind, required String title}) => context.push(
            Uri(
              path: AppRoutes.portfolioList,
              queryParameters: {'title': title, 'style': ?style, 'kind': ?kind},
            ).toString(),
          );
          Widget grid(List<Widget> children) => GridView.count(
            padding: EdgeInsets.zero,
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.82,
            children: children,
          );
          return RefreshIndicator(
            onRefresh: () => ref.refresh(portfolioTilesProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
              children: [
                grid([
                  _Tile(
                    label: 'Все проекты',
                    image: PortfolioCollage(urls: data.collage),
                    onTap: () => open(title: 'Все проекты'),
                  ),
                  for (final s in data.styles)
                    _Tile(
                      label: s.label,
                      image: PortfolioImageView(s.coverUrl),
                      onTap: () => open(style: s.style, title: s.label),
                    ),
                ]),
                if (data.kinds.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  grid([
                    for (final k in data.kinds)
                      _Tile(
                        label: k.label,
                        image: PortfolioImageView(k.coverUrl),
                        onTap: () => open(kind: k.kind, title: k.label),
                      ),
                  ]),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.image, required this.onTap});

  final String label;
  final Widget image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xB0000000)],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 0, 6, 8),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
