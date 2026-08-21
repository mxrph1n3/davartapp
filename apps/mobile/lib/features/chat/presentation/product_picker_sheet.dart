import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/data/catalog_models.dart';
import '../../catalog/data/catalog_repository.dart';

class ProductPickerSheet extends ConsumerStatefulWidget {
  const ProductPickerSheet({super.key});

  @override
  ConsumerState<ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<ProductPickerSheet> {
  final _queryController = TextEditingController();
  List<ProductSummary> _products = [];
  var _isLoading = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search([String? query]) async {
    setState(() => _isLoading = true);
    try {
      final page = await ref.read(catalogRepositoryProvider).searchProducts(
            query: query ?? _queryController.text,
            limit: 20,
          );
      setState(() => _products = page.items);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Material(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text('Выберите товар', style: Theme.of(context).textTheme.titleMedium),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _queryController,
                  decoration: InputDecoration(
                    hintText: 'Поиск товара',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () => _search(),
                      icon: const Icon(Icons.search),
                    ),
                  ),
                  onSubmitted: _search,
                ),
              ),
              if (_isLoading) const LinearProgressIndicator(),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return ListTile(
                      leading: product.imageUrl != null
                          ? Image.network(product.imageUrl!, width: 40, height: 40)
                          : const Icon(Icons.image_not_supported),
                      title: Text(product.name),
                      subtitle: Text('${product.price.toStringAsFixed(0)} ₽'),
                      onTap: () => Navigator.pop(context, product.id),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
