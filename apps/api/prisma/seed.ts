import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const categories = [
  { name: 'Мебель', slug: 'mebel', sortOrder: 1 },
  { name: 'Сантехника', slug: 'santehnika', sortOrder: 3 },
  { name: 'Керамогранит', slug: 'keramogranit', sortOrder: 4 },
  { name: 'Настенная плитка', slug: 'nastennaya-plitka', sortOrder: 5 },
  { name: 'Структурированная плитка', slug: 'strukturirovannaya-plitka', sortOrder: 6 },
  { name: 'Обои', slug: 'oboi', sortOrder: 13 },
];

const brands = [
  { name: 'Italon', slug: 'italon' },
  { name: 'Kerama Marazzi', slug: 'kerama-marazzi' },
];

async function main() {
  if (process.env.NODE_ENV === 'production' && process.env.ALLOW_PROD_SEED !== 'true') {
    throw new Error(
      'Refusing to seed in production. Set ALLOW_PROD_SEED=true to override.',
    );
  }

  console.log('Seeding catalog taxonomy (no dummy products)…');

  for (const brand of brands) {
    await prisma.brand.upsert({
      where: { slug: brand.slug },
      update: { name: brand.name },
      create: brand,
    });
  }

  for (const category of categories) {
    await prisma.category.upsert({
      where: { slug: category.slug },
      update: { name: category.name, sortOrder: category.sortOrder },
      create: category,
    });
  }

  const products = await prisma.product.count();
  console.log(
    `Taxonomy ready. Products in DB: ${products}. Use catalog:ingest-italon / catalog:ingest-kerama for SKUs.`,
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
