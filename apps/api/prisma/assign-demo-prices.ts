import { PrismaClient } from '@prisma/client';
import { Meilisearch } from 'meilisearch';
import { demoCatalogPrice } from '../src/catalog/demo-price';
import type { ProductSearchDocument } from '../src/meilisearch/meilisearch.service';

const prisma = new PrismaClient();

async function main() {
  const products = await prisma.product.findMany({
    select: {
      id: true,
      sku: true,
      category: { select: { slug: true } },
    },
  });

  let updated = 0;
  for (const product of products) {
    const price = demoCatalogPrice(product.sku, product.category.slug);
    await prisma.product.update({
      where: { id: product.id },
      data: { price },
    });
    updated += 1;
  }
  console.log(`Assigned demo prices to ${updated} products`);

  const host = process.env.MEILISEARCH_HOST;
  if (!host) {
    console.log('MEILISEARCH_HOST is not set, skip reindex');
    return;
  }

  const indexed = await prisma.product.findMany({
    include: { category: true, brand: true, attributes: true },
  });
  const client = new Meilisearch({
    host,
    apiKey: process.env.MEILISEARCH_API_KEY,
  });
  const index = client.index('products');
  const task = await index.addDocuments(
    indexed.map(
      (product): ProductSearchDocument => ({
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
          product.attributes.find((attr) => attr.key === 'Материал')?.value ??
          null,
        color:
          product.attributes.find((attr) => attr.key === 'Цвет')?.value ?? null,
        collection:
          product.attributes.find((attr) => attr.key === 'Коллекция')?.value ??
          null,
        collectionSlug: product.collectionSlug,
        inStock: product.inStock,
        isPopular: product.isPopular,
        hasDiscount: product.compareAtPrice !== null,
        createdAt: product.createdAt.getTime(),
      }),
    ),
    { primaryKey: 'id' },
  );
  await client.tasks.waitForTask(task.taskUid);
  console.log(`Meilisearch reindexed ${indexed.length} products`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
