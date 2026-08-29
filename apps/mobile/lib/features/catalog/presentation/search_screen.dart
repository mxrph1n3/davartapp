import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/product_display.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../auth/presentation/require_login.dart';
import '../../commerce/presentation/commerce_notifier.dart';
import '../../staff/presentation/staff_cart_actions.dart';
import 'search_notifier.dart';
import 'widgets/catalog_skeleton.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _scrollController.addListener(_onScroll);

    if (widget.initialQuery.isNotEmpty) {
      Future<void>.delayed(Duration.zero, () {
        ref.read(searchProvider.notifier).search(widget.initialQuery);
        ref.read(favoritesProvider.notifier).loadFavorites();
      });
    } else {
      Future<void>.delayed(Duration.zero, () {
        ref.read(favoritesProvider.notifier).loadFavorites();
      });
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(searchProvider.notifier).loadMore();
    }
  }

  void _submitSearch() {
    ref.read(searchProvider.notifier).search(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final state = ref.watch(searchProvider);

    final favoritesState = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppBackButton(
          fallback: catalogPathForRole(ref.watch(authProvider).user?.role),
        ),
        title: TextField(
          controller: _controller,
          autofocus: widget.initialQuery.isEmpty,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Поиск товаров...',
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _submitSearch(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _submitSearch,
          ),
        ],
      ),
      body: state.isLoading && state.products.isEmpty
          ? const CatalogSkeleton()
          : state.errorMessage != null && state.products.isEmpty
              ? ErrorState(
                  message: state.errorMessage!,
                  onRetry: _submitSearch,
                )
              : state.query.isEmpty
                  ? const Center(child: Text('Введите запрос для поиска'))
                  : state.products.isEmpty
                      ? const EmptyState(
                          icon: Icons.search_off,
                          title: 'Ничего не найдено',
                          subtitle: 'Попробуйте другой запрос',
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(AppSpacing.screenPadding),
                          itemCount: state.products.length +
                              (state.isLoadingMore ? 1 : 0),
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: colors.divider,
                          ),
                          itemBuilder: (context, index) {
                            if (index >= state.products.length) {
                              return const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

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
                              isFavorite:
                                  favoritesState.isFavorite(product.id),
                              onTap: () => context.push(
                                productPathForRole(
                                  ref.read(authProvider).user?.role,
                                  product.id,
                                ),
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
    );
  }
}
