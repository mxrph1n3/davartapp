import { PrismaClient } from '@prisma/client';
import { Meilisearch } from 'meilisearch';
import { ingestKeramaFromSitemap } from '../src/catalog/kerama/kerama-ingest';
import { fetchKeramaCatalog } from '../src/catalog/kerama/kerama-parser';
import type { ProductSearchDocument } from '../src/meilisearch/meilisearch.service';

const prisma = new PrismaClient();

function argValue(name: string): string | undefined {
  const prefix = `${name}=`;
  const found = process.argv.find((arg) => arg.startsWith(prefix));
  return found?.slice(prefix.length);
}

async function reindexAll() {
  const host = process.env.MEILISEARCH_HOST;
  if (!host) {
    console.log('MEILISEARCH_HOST is not set, skip reindex');
    return;
  }

  const products = await prisma.product.findMany({
    include: { category: true, brand: true, attributes: true },
  });

  const documents: ProductSearchDocument[] = products.map((product) => ({
    id: product.id,
    name: product.name,
    sku: product.sku,
    description: product.description,
    price: Number(product.price),
    categoryId: product.categoryId,
    categoryName: product.category.name,
    brandId: product.brandId,
    brandName: product.brand?.name ?? null,
    material:
      product.attributes.find((attr) => attr.key === 'Материал')?.value ?? null,
    color: product.attributes.find((attr) => attr.key === 'Цвет')?.value ?? null,
    collection:
      product.attributes.find((attr) => attr.key === 'Коллекция')?.value ??
      null,
    collectionSlug: product.collectionSlug,
    inStock: product.inStock,
    isPopular: product.isPopular,
    hasDiscount: product.compareAtPrice !== null,
    createdAt: product.createdAt.getTime(),
  }));

  const client = new Meilisearch({
    host,
    apiKey: process.env.MEILISEARCH_API_KEY,
  });
  const index = client.index('products');
  await index.updateFilterableAttributes([
    'categoryId',
    'brandId',
    'material',
    'color',
    'collection',
    'collectionSlug',
    'inStock',
    'hasDiscount',
    'price',
  ]);
  await index.updateSearchableAttributes([
    'name',
    'sku',
    'description',
    'brandName',
    'categoryName',
    'material',
    'color',
    'collection',
  ]);
  await index.addDocuments(documents, { primaryKey: 'id' });
  console.log(`Meilisearch reindexed ${documents.length} products`);
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const limitRaw = argValue('--limit');
  const limit = limitRaw ? Number(limitRaw) : undefined;

  if (dryRun) {
    console.log('Fetching Kerama Marazzi catalog (dry-run)…');
    const products = await fetchKeramaCatalog({ limit: limit ?? 8 });
    const collections = new Set(
      products.map((item) => item.collectionName).filter(Boolean),
    );
    const byCategory = products.reduce<Record<string, number>>((acc, item) => {
      acc[item.category.slug] = (acc[item.category.slug] ?? 0) + 1;
      return acc;
    }, {});
    console.log(`Parsed ${products.length} SKUs`);
    console.log(`Collections matched: ${collections.size}`);
    console.log('By category:', byCategory);
    console.log(products.slice(0, 5));
    return;
  }

  console.log('Ingesting Kerama Marazzi catalog from sitemap-iblock-9…');
  const result = await ingestKeramaFromSitemap(prisma, { limit });
  console.log(
    `Ingested Kerama: created=${result.created} updated=${result.updated} total=${result.total} images=${result.imagesMirrored}`,
  );
  await reindexAll();
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
