export const KERAMA_ORIGIN = 'https://kerama-marazzi.com';
export const KERAMA_SITEMAP = `${KERAMA_ORIGIN}/sitemap.xml`;
export const KERAMA_CATALOG_SITEMAP = `${KERAMA_ORIGIN}/sitemap-iblock-9.xml`;

const USER_AGENT =
  'Mozilla/5.0 (compatible; DavartCatalogIngest/1.0; +https://davart.app)';

const RU_GEO_COOKIE =
  'geo=%7B%22city_id%22%3Anull%2C%22region_id%22%3Anull%2C%22country_id%22%3A%221%22%2C%22country_code%22%3A%22RU%22%2C%22COUNTRY_LANG%22%3A%22ru%22%2C%22LANG%22%3A%22ru%22%7D';

const SIZE_RE =
  /(\d+(?:[.,]\d+)?)\s*[xх×]\s*(\d+(?:[.,]\d+)?)(?:\s*[xх×]\s*(\d+(?:[.,]\d+)?))?/i;

export type KeramaCategory = {
  slug: string;
  name: string;
  material: string;
  sortOrder: number;
};

export const KERAMA_CATEGORIES: Record<string, KeramaCategory> = {
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
  oboi: {
    slug: 'oboi',
    name: 'Обои',
    material: 'Обои',
    sortOrder: 13,
  },
  santehnika: {
    slug: 'santehnika',
    name: 'Сантехника',
    material: 'Сантехника',
    sortOrder: 3,
  },
  mebel: {
    slug: 'mebel',
    name: 'Мебель',
    material: 'Мебель',
    sortOrder: 1,
  },
};

const PATH_CATEGORY: Record<string, KeramaCategory> = {
  gres: KERAMA_CATEGORIES.keramogranit,
  ceramic_tile: KERAMA_CATEGORIES['nastennaya-plitka'],
  wallcoverings: KERAMA_CATEGORIES.oboi,
  'bathroom-furniture': KERAMA_CATEGORIES.mebel,
  mirrors: KERAMA_CATEGORIES.mebel,
  sinks: KERAMA_CATEGORIES.santehnika,
  'toilet-bowls': KERAMA_CATEGORIES.santehnika,
  bide: KERAMA_CATEGORIES.santehnika,
  'basin-faucets': KERAMA_CATEGORIES.santehnika,
  'bath-faucets': KERAMA_CATEGORIES.santehnika,
  'bidet-faucets': KERAMA_CATEGORIES.santehnika,
  'hygienic-showers': KERAMA_CATEGORIES.santehnika,
  'shower-systems': KERAMA_CATEGORIES.santehnika,
  'shower-enclosures-and-tray': KERAMA_CATEGORIES.santehnika,
  drain: KERAMA_CATEGORIES.santehnika,
  'aksessuary-dlya-vannoy-komnaty': KERAMA_CATEGORIES.santehnika,
};

export type KeramaProductDraft = {
  supplierSku: string;
  name: string;
  size: string | null;
  collectionSlug: string | null;
  collectionName: string | null;
  imageUrl: string;
  sourceUrl: string;
  category: KeramaCategory;
  inStock: boolean;
  price: number;
};

type FetchLike = (
  input: string,
  init?: { headers?: Record<string, string>; redirect?: RequestRedirect },
) => Promise<{
  ok: boolean;
  status: number;
  url?: string;
  headers?: { get: (name: string) => string | null };
  text: () => Promise<string>;
}>;

function decodeXml(value: string): string {
  return value
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

export function normalizeKeramaImage(url: string): string {
  const trimmed = url.trim();
  if (!trimmed) return '';
  if (trimmed.startsWith('//')) return `https:${trimmed}`;
  if (trimmed.startsWith('/')) return `${KERAMA_ORIGIN}${trimmed}`;
  return trimmed.replace('https://kerama-marazzi/', `${KERAMA_ORIGIN}/`);
}

export function categoryFromPath(pathname: string): KeramaCategory | null {
  const parts = pathname.replace(/\/+$/, '').split('/').filter(Boolean);
  const catalogIndex = parts.indexOf('catalog');
  if (catalogIndex < 0 || !parts[catalogIndex + 1]) return null;
  return PATH_CATEGORY[parts[catalogIndex + 1]] ?? null;
}

export function sanitizeKeramaSku(sku: string): string {
  return sku
    .trim()
    .replace(/[\\/]+/g, '-')
    .replace(/\s+/g, '')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

export function parseKeramaProductUrls(xml: string): string[] {
  const locs = (xml.match(/<loc>([^<]+)<\/loc>/g) ?? []).map((tag) =>
    decodeXml(tag.replace(/<\/?loc>/g, '')),
  );
  const urls: string[] = [];
  for (const loc of locs) {
    try {
      const url = new URL(loc);
      if (!url.hostname.endsWith('kerama-marazzi.com')) continue;
      const parts = url.pathname.replace(/\/+$/, '').split('/').filter(Boolean);
      if (parts[0] !== 'catalog' || parts.length < 3) continue;
      if (!PATH_CATEGORY[parts[1]]) continue;
      urls.push(`${KERAMA_ORIGIN}${url.pathname.replace(/\/+$/, '')}/`);
    } catch {
      continue;
    }
  }
  return [...new Set(urls)];
}

function parseSize(name: string): string | null {
  const match = name.match(SIZE_RE);
  if (!match) return null;
  const parts = [match[1], match[2], match[3]]
    .filter(Boolean)
    .map((part) => part.replace(',', '.'));
  return `${parts.join('×')} см`;
}

function slugify(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/['"]/g, '')
    .replace(/[^a-z0-9а-яё]+/gi, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80);
}

type JsonLd = Record<string, unknown>;

/** A JSON-LD value as text, the way String() read it before: lists joined by commas, objects skipped. */
function jsonText(value: unknown): string {
  if (typeof value === 'string') return value;
  if (typeof value === 'number' || typeof value === 'boolean')
    return String(value);
  if (Array.isArray(value)) return value.map(jsonText).join(',');
  return '';
}

function parseJsonLdBlocks(html: string): JsonLd[] {
  const blocks =
    html.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/gi) ??
    [];
  const result: JsonLd[] = [];
  for (const block of blocks) {
    const inner = block
      .replace(/^<script[^>]*>/i, '')
      .replace(/<\/script>$/i, '');
    try {
      const parsed = JSON.parse(inner) as unknown;
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        result.push(parsed as JsonLd);
      }
    } catch {
      continue;
    }
  }
  return result;
}

function stripTags(value: string): string {
  return decodeXml(value)
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export function parseKeramaProductHtml(
  html: string,
  sourceUrl: string,
): KeramaProductDraft | null {
  const pathname = (() => {
    try {
      return new URL(sourceUrl).pathname;
    } catch {
      return sourceUrl;
    }
  })();
  const category = categoryFromPath(pathname);
  if (!category) return null;

  const docs = parseJsonLdBlocks(html);
  const product = docs.find((doc) => doc['@type'] === 'Product');
  if (!product) return null;

  const sku = sanitizeKeramaSku(jsonText(product.sku));
  const name = stripTags(jsonText(product.name));
  if (!sku || !name) return null;

  const image = normalizeKeramaImage(jsonText(product.image));
  const offers =
    product.offers && typeof product.offers === 'object'
      ? (product.offers as JsonLd)
      : {};
  const availability = jsonText(offers.availability);
  const priceRaw = Number(offers.price);
  const breadcrumb = docs.find((doc) => doc['@type'] === 'BreadcrumbList');
  let collectionName: string | null = null;
  let collectionSlug: string | null = null;
  const elements = breadcrumb?.itemListElement;
  if (Array.isArray(elements)) {
    for (const item of elements) {
      if (!item || typeof item !== 'object') continue;
      const row = item as JsonLd;
      const itemUrl = jsonText(row.item);
      if (itemUrl.includes('/catalog/series/')) {
        collectionName = stripTags(jsonText(row.name)) || null;
        const slugPart = itemUrl.replace(/\/+$/, '').split('/').pop();
        collectionSlug = slugPart ? slugify(slugPart) : null;
      }
    }
  }

  return {
    supplierSku: `km-${sku}`,
    name,
    size: parseSize(name),
    collectionSlug,
    collectionName,
    imageUrl: image,
    sourceUrl,
    category,
    inStock: /InStock/i.test(availability),
    price: Number.isFinite(priceRaw) && priceRaw > 0 ? priceRaw : 0,
  };
}

function keramaHeaders(): Record<string, string> {
  return {
    'User-Agent': USER_AGENT,
    Accept: 'text/html,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'ru-RU,ru;q=0.9',
    Cookie: RU_GEO_COOKIE,
  };
}

async function fetchText(url: string, fetchImpl: FetchLike): Promise<string> {
  let current = url;
  for (let hop = 0; hop < 8; hop += 1) {
    const response = await fetchImpl(current, {
      headers: keramaHeaders(),
      redirect: 'manual',
    });
    if (response.status >= 300 && response.status < 400) {
      const location = response.headers?.get('location');
      if (!location) {
        throw new Error(`Kerama redirect without Location for ${current}`);
      }
      const next = new URL(location, current).toString();
      if (/\/en(\/|$)/i.test(next)) {
        throw new Error(`Kerama EN redirect ${current} -> ${next}`);
      }
      current = next;
      continue;
    }
    if (!response.ok) {
      throw new Error(`Kerama fetch failed ${response.status} for ${current}`);
    }
    return response.text();
  }
  throw new Error(`Kerama too many redirects for ${url}`);
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function mapPool<T, R>(
  items: T[],
  concurrency: number,
  mapper: (item: T, index: number) => Promise<R>,
): Promise<R[]> {
  const results = new Array<R>(items.length);
  let next = 0;
  async function worker() {
    while (next < items.length) {
      const index = next;
      next += 1;
      results[index] = await mapper(items[index], index);
    }
  }
  await Promise.all(
    Array.from({ length: Math.min(concurrency, items.length) }, () => worker()),
  );
  return results;
}

export async function fetchKeramaProductUrls(options?: {
  fetch?: FetchLike;
  limit?: number;
}): Promise<string[]> {
  const fetchImpl = options?.fetch ?? fetch;
  const xml = await fetchText(KERAMA_CATALOG_SITEMAP, fetchImpl);
  const urls = parseKeramaProductUrls(xml);
  if (options?.limit && options.limit > 0) {
    return urls.slice(0, options.limit);
  }
  return urls;
}

export async function fetchKeramaProductDraft(
  url: string,
  fetchImpl: FetchLike = fetch,
): Promise<KeramaProductDraft | null> {
  const html = await fetchText(url, fetchImpl);
  return parseKeramaProductHtml(html, url);
}

export async function fetchKeramaCatalog(options?: {
  fetch?: FetchLike;
  limit?: number;
  concurrency?: number;
}): Promise<KeramaProductDraft[]> {
  const fetchImpl = options?.fetch ?? fetch;
  const urls = await fetchKeramaProductUrls({
    fetch: fetchImpl,
    limit: options?.limit,
  });

  const drafts = await mapPool(
    urls,
    options?.concurrency ?? 3,
    async (url, index) => {
      if ((index + 1) % 100 === 0) {
        console.log(`Kerama pages ${index + 1}/${urls.length}`);
      }
      try {
        const draft = await fetchKeramaProductDraft(url, fetchImpl);
        await sleep(120);
        return draft;
      } catch (error) {
        console.warn(
          `Skip ${url}: ${error instanceof Error ? error.message : error}`,
        );
        return null;
      }
    },
  );

  return drafts.filter((item): item is KeramaProductDraft => item !== null);
}
