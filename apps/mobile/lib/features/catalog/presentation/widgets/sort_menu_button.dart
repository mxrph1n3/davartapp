import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog_models.dart';
import '../catalog_notifier.dart';

class SortMenuButton extends ConsumerWidget {
  const SortMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(catalogProvider).sort;

    return PopupMenuButton<ProductSort>(
      initialValue: sort,
      onSelected: ref.read(catalogProvider.notifier).setSort,
      itemBuilder: (context) => ProductSort.values
          .map(
            (item) => PopupMenuItem(
              value: item,
              child: Text(item.label),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            const Icon(Icons.sort, size: 20),
            const SizedBox(width: 4),
            Text(sort.label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
