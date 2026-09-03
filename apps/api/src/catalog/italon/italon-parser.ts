import { matchItalonCollection } from './italon-collections';

export const ITALON_ORIGIN = 'https://www.italonceramica.ru';
export const ITALON_SITEMAP = `${ITALON_ORIGIN}/sitemap.xml`;

const USER_AGENT =
  'Mozilla/5.0 (compatible; DavartCatalogIngest/1.0; +https://davart.app)';

const SIZE_RE = /(\d+(?:[.,]\d+)?)\s*[xх×]\s*(\d+(?:[.,]\d+)?)/i;
const SKU_RE = /\/articoli\/(\d+)/i;

export type ItalonCategory = {
  slug: string;
  name: string;
  material: string;
  sortOrder: number;
};

export const ITALON_CATEGORIES: Record<string, ItalonCategory> = {
  keramogranit: {
    slug: 'keramogranit',
    name: 'Керамогранит',
    material: 'Керамогранит',
    sortOrder: 4,
  },
  'nastennaya-plitka': {
    slug: 'nastennaya-plitka',
    name: 'Настенная плитка',
    material: 'Керамическая плитка',
    sortOrder: 5,
  },
  'italon-contract': {
    slug: 'italon-contract',
    name: 'Italon Contract',
    material: 'Керамогранит',
    sortOrder: 6,
  },
  'strukturirovannaya-plitka': {
    slug: 'strukturirovannaya-plitka',
    name: 'Структурированная плитка',
    material: 'Керамогранит',
    sortOrder: 7,
  },
};

export type ItalonProductDraft = {
  supplierSku: string;
  name: string;
  size: string | null;
  collectionSlug: string | null;
  collectionName: string | null;
  imageUrl: string;
  sourceUrl: string;
  category: ItalonCategory;
  priority: number;
};

type FetchLike = (
  input: string,
  init?: { headers?: Record<string, string> },
) => Promise<{ ok: boolean; status: number; text: () => Promise<string> }>;

type ListingClass = {
  category: ItalonCategory;
  sourceUrl: string;
  priority: number;
};

function normalizeUrl(value: string): string {
  const trimmed = value.trim();
  if (trimmed.startsWith('//')) return `https:${trimmed}`;
  return trimmed;
}

function upgradeImageUrl(url: string): string {
  return normalizeUrl(url).replace(
    /file\.italonceramica\.ru\/\d+x\d+\//i,
    'file.italonceramica.ru/600x600/',
  );
}

function parseSize(title: string): string | null {
  const match = title.match(SIZE_RE);
  if (!match) return null;
  return `${match[1].replace(',', '.')}×${match[2].replace(',', '.')} см`;
}

function decodeXml(value: string): string {
  return value
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

function hasCyrillic(value: string): boolean {
  return /[а-яё]/i.test(value);
}

/** RU catalog listings only — IT/EN duplicate the same SKUs. */
export function classifyRuListing(loc: string): ListingClass | null {
  let url: URL;
  try {
    url = new URL(normalizeUrl(loc));
  } catch {
    return null;
  }
  if (!url.hostname.endsWith('italonceramica.ru')) return null;

  const path = url.pathname
    .replace(/\/+/g, '/')
    .replace(/\/$/, '')
    .toLowerCase();
  if (!path.startsWith('/ru/')) return null;
  if (
    /\/(dealer|showrooms|home|meeting|realizovannye-proekty|novosti|o-kompanii)\b/.test(
      path,
    )
  ) {
    return null;
  }

  const sourceUrl = `${ITALON_ORIGIN}${url.pathname.replace(/\/+$/, '')}/`;

  if (
    path.includes('/kollektsii/keramogranit') ||
    path.includes('/kollektsii-keramogranit')
  ) {
    return {
      category: ITALON_CATEGORIES.keramogranit,
      sourceUrl,
      priority: 100,
    };
  }
  if (path.includes('/nastennayaplitka')) {
    return {
      category: ITALON_CATEGORIES['nastennaya-plitka'],
      sourceUrl,
      priority: 90,
    };
  }
  if (path.includes('/kollektsii/contract')) {
    return {
      category: ITALON_CATEGORIES['italon-contract'],
      sourceUrl,
      priority: 80,
    };
  }
  if (path.includes('strukturirovannaya') || path.includes('/poverhnost/')) {
    return {
      category: ITALON_CATEGORIES['strukturirovannaya-plitka'],
      sourceUrl,
      priority: 70,
    };
  }
  if (path.includes('/kollektsii/')) {
    return {
      category: ITALON_CATEGORIES.keramogranit,
      sourceUrl,
      priority: 10,
    };
  }
  return null;
}

function preferDraft(
  current: ItalonProductDraft | undefined,
  next: ItalonProductDraft,
): ItalonProductDraft {
  if (!current) return next;
  if (next.priority !== current.priority) {
    return next.priority > current.priority ? next : current;
  }
  if (hasCyrillic(next.name) && !hasCyrillic(current.name)) return next;
  return current;
}

export function parseItalonImageSitemap(xml: string): ItalonProductDraft[] {
  const blocks = xml.match(/<url>([\s\S]*?)<\/url>/g) ?? [];
  const bySku = new Map<string, ItalonProductDraft>();

  for (const block of blocks) {
    const locMatch = block.match(/<loc>([^<]+)<\/loc>/);
    if (!locMatch) continue;
    const listing = classifyRuListing(locMatch[1]);
    if (!listing) continue;

    const images = block.match(/<image:image>([\s\S]*?)<\/image:image>/g) ?? [];
    for (const image of images) {
      const imageLoc = image.match(/<image:loc>([^<]+)<\/image:loc>/)?.[1];
      const title = decodeXml(
        image.match(/<image:title>([^<]+)<\/image:title>/)?.[1] ?? '',
      ).trim();
      if (!imageLoc) continue;

      const sku = imageLoc.match(SKU_RE)?.[1];
      if (!sku) continue;

      const collection = matchItalonCollection(title);
      const draft: ItalonProductDraft = {
        supplierSku: sku,
        name: title || `Italon ${sku}`,
        size: parseSize(title),
        collectionSlug: collection?.slug ?? null,
        collectionName: collection?.name ?? null,
        imageUrl: upgradeImageUrl(imageLoc),
        sourceUrl: listing.sourceUrl,
        category: listing.category,
        priority: listing.priority,
      };
      bySku.set(sku, preferDraft(bySku.get(sku), draft));
    }
  }

  return [...bySku.values()];
}

/** @deprecated use parseItalonImageSitemap */
export const parseKeramogranitImageSitemap = parseItalonImageSitemap;

function parseSitemapIndex(xml: string): string[] {
  return (xml.match(/<loc>([^<]+)<\/loc>/g) ?? [])
    .map((tag) => tag.replace(/<\/?loc>/g, ''))
    .filter((loc) => /sitemap-immagini-\d+\.xml/i.test(loc));
}

async function fetchText(url: string, fetchImpl: FetchLike): Promise<string> {
  const response = await fetchImpl(url, {
    headers: {
      'User-Agent': USER_AGENT,
      Accept: 'application/xml,text/xml,*/*',
    },
  });
  if (!response.ok) {
    throw new Error(`Italon fetch failed ${response.status} for ${url}`);
  }
  return response.text();
}

export async function fetchItalonCatalog(options?: {
  fetch?: FetchLike;
}): Promise<ItalonProductDraft[]> {
  const fetchImpl = options?.fetch ?? fetch;
  const indexXml = await fetchText(ITALON_SITEMAP, fetchImpl);
  const imageSitemaps = parseSitemapIndex(indexXml);
  if (imageSitemaps.length === 0) {
    throw new Error('Italon sitemap has no image sitemaps');
  }

  const bySku = new Map<string, ItalonProductDraft>();
  for (const [index, sitemapUrl] of imageSitemaps.entries()) {
    const xml = await fetchText(sitemapUrl, fetchImpl);
    for (const product of parseItalonImageSitemap(xml)) {
      bySku.set(
        product.supplierSku,
        preferDraft(bySku.get(product.supplierSku), product),
      );
    }
    if ((index + 1) % 10 === 0 || index + 1 === imageSitemaps.length) {
      console.log(
        `Italon sitemaps ${index + 1}/${imageSitemaps.length}, SKUs ${bySku.size}`,
      );
    }
  }

  return [...bySku.values()].sort((a, b) =>
    a.supplierSku.localeCompare(b.supplierSku),
  );
}

export async function fetchItalonKeramogranit(options?: {
  fetch?: FetchLike;
}): Promise<ItalonProductDraft[]> {
  const products = await fetchItalonCatalog(options);
  return products.filter((product) => product.category.slug === 'keramogranit');
}
