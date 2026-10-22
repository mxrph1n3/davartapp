/** Stable Unsplash fallbacks when product.imageUrl is null (staging demos). */

const PRODUCT_BY_CATEGORY: Record<string, string[]> = {
  mebel: [
    'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&w=1000&h=1000&q=80',
    'https://images.unsplash.com/photo-1567538096630-e0c55bd6374c?auto=format&fit=crop&w=1000&h=1000&q=80',
    'https://images.unsplash.com/photo-1592078615290-033ee584e267?auto=format&fit=crop&w=1000&h=1000&q=80',
  ],
  oboi: [
    'https://images.unsplash.com/photo-1615874959474-d609969a20ed?auto=format&fit=crop&w=1000&h=1000&q=80',
    'https://images.unsplash.com/photo-1615529328331-f8917597711f?auto=format&fit=crop&w=1000&h=1000&q=80',
  ],
  santehnika: [
    'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?auto=format&fit=crop&w=1000&h=1000&q=80',
    'https://images.unsplash.com/photo-1552321554-5fefe8c9ef14?auto=format&fit=crop&w=1000&h=1000&q=80',
  ],
  plitka: [
    'https://images.unsplash.com/photo-1600607686527-6fb886090705?auto=format&fit=crop&w=1000&h=1000&q=80',
    'https://images.unsplash.com/photo-1631679706909-1844bbd07221?auto=format&fit=crop&w=1000&h=1000&q=80',
  ],
  keramogranit: [
    'https://images.unsplash.com/photo-1618220179428-22790b461013?auto=format&fit=crop&w=1000&h=1000&q=80',
    'https://images.unsplash.com/photo-1600607686527-6fb886090705?auto=format&fit=crop&w=1000&h=1000&q=80',
  ],
};

const CATEGORY_ALIASES: Record<string, string> = {
  'nastennaya-plitka': 'plitka',
  'strukturirovannaya-plitka': 'plitka',
  wallpaper: 'oboi',
  furniture: 'mebel',
  bathroom: 'santehnika',
  tile: 'plitka',
};

function stableIndex(seed: string, modulo: number): number {
  if (modulo <= 0) return 0;
  let hash = 0;
  for (let i = 0; i < seed.length; i += 1) {
    hash = 0x1fffffff & (hash + seed.charCodeAt(i));
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    hash ^= hash >> 6;
  }
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash ^= hash >> 11;
  hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  return Math.abs(hash) % modulo;
}

function resolveCategoryKey(categorySlug?: string | null): string {
  const slug = (categorySlug ?? '').trim().toLowerCase();
  if (!slug) return 'mebel';
  if (PRODUCT_BY_CATEGORY[slug]) return slug;
  if (CATEGORY_ALIASES[slug]) return CATEGORY_ALIASES[slug];
  if (slug.includes('plit')) return 'plitka';
  if (slug.includes('oboi') || slug.includes('wall')) return 'oboi';
  if (slug.includes('santeh') || slug.includes('bath')) return 'santehnika';
  if (slug.includes('keramo')) return 'keramogranit';
  if (
    slug.includes('mebel') ||
    slug.includes('sofa') ||
    slug.includes('divan')
  ) {
    return 'mebel';
  }
  return 'mebel';
}

export function resolveProductImageUrl(params: {
  productId: string;
  categorySlug?: string | null;
  imageUrl?: string | null;
}): string {
  if (params.imageUrl && params.imageUrl.trim()) {
    return params.imageUrl.trim();
  }
  const key = resolveCategoryKey(params.categorySlug);
  const pool = PRODUCT_BY_CATEGORY[key] ?? PRODUCT_BY_CATEGORY.mebel;
  return pool[stableIndex(params.productId, pool.length)];
}
