import '../../../core/utils/demo_media.dart';

enum ProductSort {
  popular('popular', 'Популярные'),
  priceAsc('price_asc', 'Сначала дешевле'),
  priceDesc('price_desc', 'Сначала дороже'),
  newest('new', 'Новинки'),
  discount('discount', 'Скидки'),
  stock('stock', 'В наличии');

  const ProductSort(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ProductSort fromApi(String value) {
    return ProductSort.values.firstWhere(
      (sort) => sort.apiValue == value,
      orElse: () => ProductSort.popular,
    );
  }
}

class CatalogFilters {
  const CatalogFilters({
    this.minPrice,
    this.maxPrice,
    this.brandId,
    this.material,
    this.color,
    this.collection,
    this.inStock,
    this.attrs = const {},
    this.brandIds = const {},
  });

  /// Characteristic filters: key → chosen values (OR inside a key, AND between keys).
  final Map<String, Set<String>> attrs;
  final Set<String> brandIds;

  final double? minPrice;
  final double? maxPrice;
  final String? brandId;
  final String? material;
  final String? color;
  final String? collection;
  final bool? inStock;

  bool get hasActiveFilters =>
      minPrice != null ||
      maxPrice != null ||
      brandId != null ||
      material != null ||
      color != null ||
      collection != null ||
      inStock != null ||
      attrs.values.any((v) => v.isNotEmpty) ||
      brandIds.isNotEmpty;

  int get activeCount =>
      attrs.values.where((v) => v.isNotEmpty).length +
      (brandIds.isNotEmpty || brandId != null ? 1 : 0) +
      (minPrice != null || maxPrice != null ? 1 : 0) +
      (inStock == true ? 1 : 0);

  CatalogFilters copyWith({
    double? minPrice,
    double? maxPrice,
    String? brandId,
    String? material,
    String? color,
    String? collection,
    bool? inStock,
    Map<String, Set<String>>? attrs,
    Set<String>? brandIds,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
    bool clearBrandId = false,
    bool clearMaterial = false,
    bool clearColor = false,
    bool clearCollection = false,
    bool clearInStock = false,
  }) {
    return CatalogFilters(
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      brandId: clearBrandId ? null : (brandId ?? this.brandId),
      material: clearMaterial ? null : (material ?? this.material),
      color: clearColor ? null : (color ?? this.color),
      collection: clearCollection ? null : (collection ?? this.collection),
      inStock: clearInStock ? null : (inStock ?? this.inStock),
      attrs: attrs ?? this.attrs,
      brandIds: brandIds ?? this.brandIds,
    );
  }

  static const empty = CatalogFilters();
}

class FilterBrand {
  const FilterBrand({required this.id, required this.name, required this.slug});

  factory FilterBrand.fromJson(Map<String, dynamic> json) {
    return FilterBrand(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
    );
  }

  final String id;
  final String name;
  final String slug;
}

class PriceRange {
  const PriceRange({required this.min, required this.max});

  factory PriceRange.fromJson(Map<String, dynamic> json) {
    return PriceRange(
      min: (json['min'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
    );
  }

  final double min;
  final double max;
}

class FilterCollection {
  const FilterCollection({required this.slug, required this.name});

  factory FilterCollection.fromJson(Map<String, dynamic> json) {
    return FilterCollection(
      slug: json['slug'] as String,
      name: json['name'] as String,
    );
  }

  final String slug;
  final String name;
}

class FilterOptions {
  const FilterOptions({
    required this.brands,
    required this.materials,
    required this.colors,
    required this.collections,
    required this.priceRange,
    this.attributes = const [],
  });

  factory FilterOptions.fromJson(Map<String, dynamic> json) {
    return FilterOptions(
      brands: (json['brands'] as List<dynamic>)
          .map((item) => FilterBrand.fromJson(item as Map<String, dynamic>))
          .toList(),
      materials: (json['materials'] as List<dynamic>).cast<String>(),
      colors: (json['colors'] as List<dynamic>).cast<String>(),
      collections: (json['collections'] as List<dynamic>? ?? [])
          .map((item) => FilterCollection.fromJson(item as Map<String, dynamic>))
          .toList(),
      priceRange: PriceRange.fromJson(json['priceRange'] as Map<String, dynamic>),
      attributes: (json['attributes'] as List<dynamic>? ?? [])
          .map((item) => FilterAttribute.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final List<FilterAttribute> attributes;
  final List<FilterBrand> brands;
  final List<String> materials;
  final List<String> colors;
  final List<FilterCollection> collections;
  final PriceRange priceRange;
}

class FilterAttribute {
  const FilterAttribute({required this.key, required this.values});

  factory FilterAttribute.fromJson(Map<String, dynamic> json) {
    return FilterAttribute(
      key: json['key'] as String,
      values: [
        for (final v in json['values'] as List<dynamic>? ?? [])
          (value: (v as Map)['value'] as String, count: (v['count'] as num?)?.toInt() ?? 0),
      ],
    );
  }

  final String key;
  final List<({String value, int count})> values;
}

class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    required this.productCount,
    this.children = const [],
  });

  factory CatalogCategory.fromJson(Map<String, dynamic> json) {
    return CatalogCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      imageUrl: json['imageUrl'] as String?,
      productCount: (json['productCount'] as int?) ??
          (json['_count']?['products'] as int?) ??
          0,
      children: (json['children'] as List<dynamic>? ?? [])
          .map((item) => CatalogCategory.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Subcategories, shown as chips inside a shop tile.
  final List<CatalogCategory> children;
  final String id;
  final String name;
  final String slug;
  final String? imageUrl;
  final int productCount;
}

class CatalogBrand {
  const CatalogBrand({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory CatalogBrand.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const CatalogBrand(id: '', name: '', slug: '');
    }

    return CatalogBrand(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
    );
  }

  final String id;
  final String name;
  final String slug;
}

class ProductSummary {
  const ProductSummary({
    required this.id,
    required this.name,
    required this.slug,
    required this.sku,
    required this.price,
    this.compareAtPrice,
    this.imageUrl,
    this.description,
    required this.inStock,
    required this.isPopular,
    required this.category,
    required this.brand,
    this.unit = 'шт',
    this.sellByPack = false,
    this.packSize,
    this.packPieces,
    this.leadTimeMinDays,
    this.leadTimeMaxDays,
    this.highlights = const [],
    this.collectionSlug,
  });

  factory ProductSummary.fromJson(Map<String, dynamic> json) {
    final category = CatalogCategory.fromJson(
      json['category'] as Map<String, dynamic>,
    );
    final id = json['id'] as String;
    return ProductSummary(
      id: id,
      name: json['name'] as String,
      slug: json['slug'] as String,
      sku: json['sku'] as String,
      price: (json['price'] as num).toDouble(),
      compareAtPrice: (json['compareAtPrice'] as num?)?.toDouble(),
      imageUrl: demoProductImageUrl(
        productId: id,
        categorySlug: category.slug,
        imageUrl: json['imageUrl'] as String?,
      ),
      description: json['description'] as String?,
      inStock: json['inStock'] as bool? ?? false,
      isPopular: json['isPopular'] as bool? ?? false,
      category: category,
      brand: CatalogBrand.fromJson(json['brand'] as Map<String, dynamic>?),
      unit: json['unit'] as String? ?? 'шт',
      sellByPack: json['sellByPack'] as bool? ?? false,
      packSize: (json['packSize'] as num?)?.toDouble(),
      packPieces: (json['packPieces'] as num?)?.toInt(),
      leadTimeMinDays: (json['leadTimeMinDays'] as num?)?.toInt(),
      leadTimeMaxDays: (json['leadTimeMaxDays'] as num?)?.toInt(),
      highlights: (json['highlights'] as List<dynamic>? ?? []).cast<String>(),
      collectionSlug: json['collectionSlug'] as String?,
    );
  }

  /// Price is per [unit]; goods with [sellByPack] go to the cart in packs of [packSize] units.
  final String unit;
  final bool sellByPack;
  final double? packSize;
  final int? packPieces;
  final int? leadTimeMinDays;
  final int? leadTimeMaxDays;

  /// Short characteristics for list rows: size, surface, material…
  final List<String> highlights;
  final String? collectionSlug;

  /// Price of one cart unit (a pack for pack-sold goods).
  double get cartUnitPrice =>
      sellByPack && packSize != null ? price * packSize! : price;

  /// «срок 7–10 дней» for goods not in stock.
  String get leadTimeLabel {
    final a = leadTimeMinDays, b = leadTimeMaxDays;
    if (a != null && b != null && a != b) return 'срок $a–$b дней';
    if ((a ?? b) != null) return 'срок ${a ?? b} дней';
    return 'срок 7–10 дней';
  }

  final String id;
  final String name;
  final String slug;
  final String sku;
  final double price;
  final double? compareAtPrice;
  final String? imageUrl;
  final String? description;
  final bool inStock;
  final bool isPopular;
  final CatalogCategory category;
  final CatalogBrand brand;
}

class ProductAttribute {
  const ProductAttribute({required this.key, required this.value});

  factory ProductAttribute.fromJson(Map<String, dynamic> json) {
    return ProductAttribute(
      key: json['key'] as String,
      value: json['value'] as String,
    );
  }

  final String key;
  final String value;
}

class ProductDetail extends ProductSummary {
  const ProductDetail({
    required super.id,
    required super.name,
    required super.slug,
    required super.sku,
    required super.price,
    super.compareAtPrice,
    super.imageUrl,
    super.description,
    required super.inStock,
    required super.isPopular,
    required super.category,
    required super.brand,
    super.unit,
    super.sellByPack,
    super.packSize,
    super.packPieces,
    super.leadTimeMinDays,
    super.leadTimeMaxDays,
    super.highlights,
    super.collectionSlug,
    required this.attributes,
    this.images = const [],
    this.collection = const [],
    this.similar = const [],
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    final summary = ProductSummary.fromJson(json);
    final category = summary.category;
    final id = summary.id;
    List<ProductSummary> list(String key) => (json[key] as List<dynamic>? ?? [])
        .map((item) => ProductSummary.fromJson(item as Map<String, dynamic>))
        .toList();
    return ProductDetail(
      unit: summary.unit,
      sellByPack: summary.sellByPack,
      packSize: summary.packSize,
      packPieces: summary.packPieces,
      leadTimeMinDays: summary.leadTimeMinDays,
      leadTimeMaxDays: summary.leadTimeMaxDays,
      highlights: summary.highlights,
      collectionSlug: summary.collectionSlug,
      images: [
        if (summary.imageUrl != null) summary.imageUrl!,
        for (final url in (json['images'] as List<dynamic>? ?? []).cast<String>())
          if (url != summary.imageUrl) url,
      ],
      collection: list('collection'),
      similar: list('similar'),
      id: id,
      name: json['name'] as String,
      slug: json['slug'] as String,
      sku: json['sku'] as String,
      price: (json['price'] as num).toDouble(),
      compareAtPrice: (json['compareAtPrice'] as num?)?.toDouble(),
      imageUrl: demoProductImageUrl(
        productId: id,
        categorySlug: category.slug,
        imageUrl: json['imageUrl'] as String?,
      ),
      description: json['description'] as String?,
      inStock: json['inStock'] as bool? ?? false,
      isPopular: json['isPopular'] as bool? ?? false,
      category: category,
      brand: CatalogBrand.fromJson(json['brand'] as Map<String, dynamic>?),
      attributes: (json['attributes'] as List<dynamic>? ?? [])
          .map((item) => ProductAttribute.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final List<ProductAttribute> attributes;
  final List<String> images;
  final List<ProductSummary> collection;
  final List<ProductSummary> similar;
}

class ProductsPage {
  const ProductsPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  factory ProductsPage.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] as Map<String, dynamic>;

    return ProductsPage(
      items: (json['items'] as List<dynamic>)
          .map((item) => ProductSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: pagination['page'] as int,
      totalPages: pagination['totalPages'] as int,
      total: pagination['total'] as int,
    );
  }

  final List<ProductSummary> items;
  final int page;
  final int totalPages;
  final int total;
}
