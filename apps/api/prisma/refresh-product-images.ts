import { PrismaClient } from '@prisma/client';
import { createProductImageStore } from './seed-product-images';

/**
 * Uploads thematic category images to MinIO and rewrites product.imageUrl
 * without deleting catalog / carts / orders.
 */
const prisma = new PrismaClient();

async function main() {
  console.log('Refreshing product images…');
  const images = createProductImageStore();
  const result = await images.prepare();

  const products = await prisma.product.findMany({
    where: { sku: { startsWith: 'DAV-' } },
    select: {
      id: true,
      category: { select: { slug: true } },
    },
    orderBy: [{ categoryId: 'asc' }, { createdAt: 'asc' }],
  });

  const counters = new Map<string, number>();
  let updated = 0;

  for (const product of products) {
    const slug = product.category.slug;
    const next = (counters.get(slug) ?? 0) + 1;
    counters.set(slug, next);
    const imageUrl = images.urlFor(slug, next);
    await prisma.product.update({
      where: { id: product.id },
      data: { imageUrl },
    });
    updated += 1;
  }

  console.log(`Updated ${updated} products (images: ${result.mode})`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
