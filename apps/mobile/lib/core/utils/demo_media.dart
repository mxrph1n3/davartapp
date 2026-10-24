/// Curated interior / product photos for demo & store reviews
/// when catalog rows have null `imageUrl` (or picsum covers).
library;

const _interiorCovers = <String>[
  'https://images.unsplash.com/photo-1616486338812-3dadae4b4ace?auto=format&fit=crop&w=1200&h=900&q=80',
  'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?auto=format&fit=crop&w=1200&h=900&q=80',
  'https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?auto=format&fit=crop&w=1200&h=900&q=80',
  'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=1200&h=900&q=80',
  'https://images.unsplash.com/photo-1615876230403-f13c5dd11a17?auto=format&fit=crop&w=1200&h=900&q=80',
  'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?auto=format&fit=crop&w=1200&h=900&q=80',
];

const _productByCategory = <String, List<String>>{
  'mebel': [
    'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&w=1000&h=1000&q=80',
    'https://images.unsplash.com/photo-1567538096630-e0c55bd6374c?auto=format&fit=crop&w=1000&h=1000&q=80',
    'https://images.unsplash.com/photo-1592078615290-033ee584e267?auto=format&fit=crop&w=1000&h=1000&q=80',
  ],
  'oboi': [
    'https://images.unsplash.com/photo-1615874959474-d609969a20ed?auto=format&fit=crop&w=1000&h=1000&q=80',
    'https://images.unsplash.com/photo-1615529328331-f8917597711f?auto=format&fit=crop&w=1000&h=1000&q=80',
  ],
  'santehnika': [
    'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?auto=format&fit=crop&w=1000&h=1000&q=80',
    'https://images.unsplash.com/photo-1552321554-5fefe8c9ef14?auto=format&fit=crop&w=1000&h=1000&q=80',
  ],
  'plitka': [
    'https://images.unsplash.com/photo-1600607686527-6fb886090705?auto=format&fit=crop&w=1000&h=1000&q=80',
    'https://images.unsplash.com/photo-1631679706909-1844bbd07221?auto=format&fit=crop&w=1000&h=1000&q=80',
  ],
  'keramogranit': [
    'https://images.unsplash.com/photo-1618220179428-22790b461013?auto=format&fit=crop&w=1000&h=1000&q=80',
    'https://images.unsplash.com/photo-1600607686527-6fb886090705?auto=format&fit=crop&w=1000&h=1000&q=80',
  ],
};

const _categoryAliases = <String, String>{
  'nastennaya-plitka': 'plitka',
  'strukturirovannaya-plitka': 'plitka',
  'wallpaper': 'oboi',
  'furniture': 'mebel',
  'bathroom': 'santehnika',
  'tile': 'plitka',
};

int _stableIndex(String seed, int modulo) {
  if (modulo <= 0) return 0;
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = 0x1fffffff & (hash + unit);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    hash ^= hash >> 6;
  }
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash ^= hash >> 11;
  hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  return hash.abs() % modulo;
}

String _resolveCategoryKey(String categorySlug) {
  final slug = categorySlug.trim().toLowerCase();
  if (slug.isEmpty) return 'mebel';
  if (_productByCategory.containsKey(slug)) return slug;
  final alias = _categoryAliases[slug];
  if (alias != null) return alias;
  if (slug.contains('plit')) return 'plitka';
  if (slug.contains('oboi') || slug.contains('wall')) return 'oboi';
  if (slug.contains('santeh') || slug.contains('bath')) return 'santehnika';
  if (slug.contains('keramo')) return 'keramogranit';
  if (slug.contains('mebel') || slug.contains('sofa') || slug.contains('divan')) {
    return 'mebel';
  }
  return 'mebel';
}

String interiorCoverUrl(String seed) {
  return _interiorCovers[_stableIndex(seed, _interiorCovers.length)];
}

String demoProductImageUrl({
  required String productId,
  String categorySlug = 'mebel',
  String? imageUrl,
}) {
  if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
  final key = _resolveCategoryKey(categorySlug);
  final pool = _productByCategory[key] ?? _productByCategory['mebel']!;
  return pool[_stableIndex(productId, pool.length)];
}
