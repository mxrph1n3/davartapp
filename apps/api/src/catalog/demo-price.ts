/** Stable demo list prices so re-ingest does not reshuffle SKUs. */

const RANGES: Record<string, readonly [number, number]> = {
  keramogranit: [1290, 8900],
  'nastennaya-plitka': [890, 6900],
  'strukturirovannaya-plitka': [1490, 9900],
  oboi: [1890, 7900],
  santehnika: [3990, 54900],
  mebel: [8900, 129000],
};

export function demoCatalogPrice(sku: string, categorySlug: string): number {
  const [min, max] = RANGES[categorySlug] ?? [1990, 15900];
  let hash = 2166136261;
  for (let i = 0; i < sku.length; i += 1) {
    hash ^= sku.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  const step = 10;
  const span = Math.floor((max - min) / step);
  return min + (Math.abs(hash) % (span + 1)) * step;
}
