import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/layout/tab_page.dart';
import '../../../core/utils/product_display.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../auth/presentation/require_login.dart';
import '../../commerce/presentation/active_project_provider.dart';
import '../../commerce/presentation/commerce_notifier.dart';
import '../../commerce/presentation/project_cart_banner.dart';
import '../../commerce/presentation/project_picker_sheet.dart';
import '../../staff/presentation/staff_cart_actions.dart';
import '../../staff/presentation/working_client_banner.dart';
import '../../staff/presentation/working_client_provider.dart';
import 'catalog_notifier.dart';
import 'widgets/active_filters_chips.dart';
import 'widgets/catalog_skeleton.dart';
import 'widgets/filters_panel.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future<void>.delayed(Duration.zero, () {
      ref.read(catalogProvider.notifier).loadInitial();
      final isStaff = ref.read(authProvider).user?.role.isStudio == true;
      if (!isStaff) {
        ref.read(cartProvider.notifier).loadCart();
      }
      ref.read(favoritesProvider.notifier).loadFavorites();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(catalogProvider.notifier).loadMore();
    }
  }

  Future<void> _openFilters() async {
    final filters = await showFiltersPanel(context);

    if (filters != null && mounted) {
      await ref.read(catalogProvider.notifier).applyFilters(filters);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogProvider);
    final isStaff = ref.watch(authProvider).user?.role.isStudio == true;
    final working = ref.watch(workingClientProvider);
    final activeProject = ref.watch(activeProjectProvider);
    final ownCartCount = ref.watch(cartProvider).itemCount;
    final favoritesState = ref.watch(favoritesProvider);

    late final Widget body;
    if (state.isLoading && state.products.isEmpty) {
      body = const CatalogSkeleton();
    } else if (state.errorMessage != null && state.products.isEmpty) {
      body = ErrorState(
        message: state.errorMessage!,
        onRetry: () => ref.read(catalogProvider.notifier).refresh(),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => ref.read(catalogProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (!isStaff)
              const SliverToBoxAdapter(child: ProjectCartBanner()),
            SliverToBoxAdapter(
              child: ScreenHeader(
                title: 'Каталог',
                actions: [
                  HeaderIconButton(
                    icon: Icons.favorite_border,
                    onPressed: () => context.push(AppRoutes.favorites),
                  ),
                  if (!isStaff)
                    HeaderIconButton(
                      icon: Icons.shopping_bag_outlined,
                      badge: ownCartCount > 0 ? ownCartCount : null,
                      onPressed: () => context.go(AppRoutes.cart),
                    )
                  else if (working != null)
                    HeaderIconButton(
                      icon: Icons.shopping_bag_outlined,
                      onPressed: () async {
                        final projectId = activeProject?.id ??
                            await ensureActiveProject(
                              context,
                              ref,
                              staffClientId: working.id,
                            );
                        if (projectId != null && context.mounted) {
                          context.push(AppRoutes.staffProjectCart(projectId));
                        }
                      },
                    ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  0,
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                ),
                child: AppSearchBar(
                  hintText: 'Поиск товаров',
                  onTap: () => context.push(AppRoutes.search),
                  onFilterTap: _openFilters,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: ActiveFiltersChips(),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: CategoryChip(
                          label: 'Все',
                          selected: state.selectedCategoryId == null,
                          onSelected: (_) => ref
                              .read(catalogProvider.notifier)
                              .selectCategory(null),
                        ),
                      ),
                      ...state.categories.map(
                        (category) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: CategoryChip(
                            label: category.name,
                            selected: state.selectedCategoryId == category.id,
                            onSelected: (_) => ref
                                .read(catalogProvider.notifier)
                                .selectCategory(category.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (state.products.isEmpty && !state.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.search_off,
                  title: 'Товары не найдены',
                  subtitle: 'Попробуйте изменить фильтры или категорию',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  0,
                  AppSpacing.screenPadding,
                  AppSpacing.screenPadding,
                ),
                sliver: SliverList.separated(
                  itemCount: state.products.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    color: AppColors.divider,
                  ),
                  itemBuilder: (context, index) {
                    final product = state.products[index];
                    return ProductCard(
                      name: catalogProductTitle(
                        product.name,
                        product.brand.name,
                      ),
                      price: product.price,
                      brand: product.brand.name,
                      description: product.description,
                      imageUrl: product.imageUrl,
                      inStock: product.inStock,
                      isFavorite: favoritesState.isFavorite(product.id),
                      onTap: () => context.push(
                        AppRoutes.productDetail(product.id),
                      ),
                      onFavoriteToggle: () async {
                        try {
                          await toggleFavoriteWithLogin(
                            context,
                            ref,
                            product.id,
                          );
                        } catch (_) {}
                      },
                      onAddToCart: () async {
                        try {
                          await addProductToActiveCart(
                            ref,
                            product.id,
                            context: context,
                          );
                        } catch (_) {}
                      },
                    );
                  },
                ),
              ),
            if (state.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      );
    }

    return TabPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isStaff) const WorkingClientBanner(),
          Expanded(child: body),
        ],
      ),
    );
  }
}
