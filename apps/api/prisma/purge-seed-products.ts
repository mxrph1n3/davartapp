import { PrismaClient } from '@prisma/client';
import { Meilisearch } from 'meilisearch';

const prisma = new PrismaClient();

async function reindexRemaining() {
  const host = process.env.MEILISEARCH_HOST;
  if (!host) {
    console.log('MEILISEARCH_HOST is not set, skip reindex');
    return;
  }

  const products = await prisma.product.findMany({
    include: { category: true, brand: true, attributes: true },
  });

  const client = new Meilisearch({
    host,
    apiKey: process.env.MEILISEARCH_API_KEY,
  });
  const index = client.index('products');
  const wipe = await index.deleteAllDocuments();
  await client.tasks.waitForTask(wipe.taskUid);
  if (products.length === 0) {
    console.log('Meilisearch cleared, no products to index');
    return;
  }

  const task = await index.addDocuments(
    products.map((product) => ({
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
    })),
    { primaryKey: 'id' },
  );
  await client.tasks.waitForTask(task.taskUid);
  console.log(`Meilisearch reindexed ${products.length} products`);
}

async function main() {
  const dummy = await prisma.product.findMany({
    where: { sku: { startsWith: 'DAV-' } },
    select: { id: true },
  });
  const ids = dummy.map((item) => item.id);
  console.log(`Dummy SKUs to delete: ${ids.length}`);
  if (ids.length === 0) {
    return;
  }

  const cart = await prisma.cartItem.deleteMany({
    where: { productId: { in: ids } },
  });
  const orders = await prisma.orderItem.deleteMany({
    where: { productId: { in: ids } },
  });
  const products = await prisma.product.deleteMany({
    where: { id: { in: ids } },
  });
  console.log(
    `Removed cartItems=${cart.count} orderItems=${orders.count} products=${products.count}`,
  );

  const emptyCategories = await prisma.category.findMany({
    where: { products: { none: {} } },
    select: { id: true, slug: true },
  });
  if (emptyCategories.length > 0) {
    await prisma.category.deleteMany({
      where: { id: { in: emptyCategories.map((item) => item.id) } },
    });
    console.log(
      `Removed empty categories: ${emptyCategories.map((item) => item.slug).join(', ')}`,
    );
  }

  const emptyBrands = await prisma.brand.findMany({
    where: { products: { none: {} } },
    select: { id: true, slug: true },
  });
  if (emptyBrands.length > 0) {
    await prisma.brand.deleteMany({
      where: { id: { in: emptyBrands.map((item) => item.id) } },
    });
    console.log(
      `Removed unused brands: ${emptyBrands.map((item) => item.slug).join(', ')}`,
    );
  }

  await reindexRemaining();
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
