import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/ds/filter_chip.dart';
import '../../data/catalog_models.dart';
import '../catalog_notifier.dart';

class ActiveFiltersChips extends ConsumerWidget {
  const ActiveFiltersChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(catalogProvider);
    final filters = state.filters;
    final options = state.filterOptions;
    final chips = <Widget>[];

    if (state.searchQuery.isNotEmpty) {
      chips.add(
        ActiveFilterChip(
          label: '«${state.searchQuery}»',
          onDeleted: () => ref.read(catalogProvider.notifier).clearSearch(),
        ),
      );
    }

    if (filters.minPrice != null || filters.maxPrice != null) {
      final min = filters.minPrice?.round() ?? options?.priceRange.min.round();
      final max = filters.maxPrice?.round() ?? options?.priceRange.max.round();
      chips.add(
        ActiveFilterChip(
          label: '$min – $max ₽',
          onDeleted: () => ref.read(catalogProvider.notifier).removeFilter(
                minPrice: true,
                maxPrice: true,
              ),
        ),
      );
    }

    if (filters.brandId != null) {
      final brand = options?.brands.firstWhere(
        (item) => item.id == filters.brandId,
        orElse: () => const FilterBrand(id: '', name: 'Бренд', slug: ''),
      );
      chips.add(
        ActiveFilterChip(
          label: brand?.name ?? 'Бренд',
          onDeleted: () =>
              ref.read(catalogProvider.notifier).removeFilter(brandId: true),
        ),
      );
    }

    if (filters.material != null) {
      chips.add(
        ActiveFilterChip(
          label: filters.material!,
          onDeleted: () =>
              ref.read(catalogProvider.notifier).removeFilter(material: true),
        ),
      );
    }

    if (filters.color != null) {
      chips.add(
        ActiveFilterChip(
          label: filters.color!,
          onDeleted: () =>
              ref.read(catalogProvider.notifier).removeFilter(color: true),
        ),
      );
    }

    if (filters.collection != null) {
      final collection = options?.collections.firstWhere(
        (item) => item.slug == filters.collection,
        orElse: () => FilterCollection(
          slug: filters.collection!,
          name: filters.collection!,
        ),
      );
      chips.add(
        ActiveFilterChip(
          label: collection?.name ?? filters.collection!,
          onDeleted: () =>
              ref.read(catalogProvider.notifier).removeFilter(collection: true),
        ),
      );
    }

    if (filters.inStock == true) {
      chips.add(
        ActiveFilterChip(
          label: 'В наличии',
          onDeleted: () =>
              ref.read(catalogProvider.notifier).removeFilter(inStock: true),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => chips[index],
        ),
      ),
    );
  }
}
