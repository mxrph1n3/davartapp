import { PrismaClient, UserRole } from '@prisma/client';
import { applyTaxonomy } from './catalog-taxonomy';
import { seedDemoCatalog } from './demo-catalog';

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

const staffUsers: Array<{
  phone: string;
  name: string;
  role: UserRole;
}> = [
  { phone: '+79009999999', name: 'Анна Дизайнер', role: UserRole.designer },
  { phone: '+79009999998', name: 'Ирина Менеджер', role: UserRole.complectator },
  { phone: '+79009999997', name: 'Павел Замерщик', role: UserRole.surveyor },
  { phone: '+79009999990', name: 'Artur', role: UserRole.admin },
];

const demoProducts = [
  {
    name: 'Керамогранит Italon Contro Natural',
    slug: 'italon-contro-natural',
    sku: 'DEMO-ITL-001',
    price: 2890,
    categorySlug: 'keramogranit',
    brandSlug: 'italon',
    isPopular: true,
  },
  {
    name: 'Плитка Kerama Marazzi Беллеза',
    slug: 'kerama-belleza',
    sku: 'DEMO-KM-001',
    price: 2140,
    categorySlug: 'nastennaya-plitka',
    brandSlug: 'kerama-marazzi',
    isPopular: true,
  },
  {
    name: 'Диван Modular Soft',
    slug: 'sofa-modular-soft',
    sku: 'DEMO-MB-001',
    price: 89900,
    categorySlug: 'mebel',
    brandSlug: null,
    isPopular: true,
  },
  {
    name: 'Раковина накладная Nova',
    slug: 'sink-nova',
    sku: 'DEMO-ST-001',
    price: 12400,
    categorySlug: 'santehnika',
    brandSlug: null,
    isPopular: false,
  },
  {
    name: 'Обои Scandinavian Linen',
    slug: 'wallpaper-scandi-linen',
    sku: 'DEMO-OB-001',
    price: 3200,
    categorySlug: 'oboi',
    brandSlug: null,
    isPopular: true,
  },
  {
    name: 'Структурированная плитка Ridge',
    slug: 'tile-ridge-struct',
    sku: 'DEMO-SP-001',
    price: 3560,
    categorySlug: 'strukturirovannaya-plitka',
    brandSlug: 'italon',
    isPopular: false,
  },
];

async function main() {
  if (process.env.NODE_ENV === 'production' && process.env.ALLOW_PROD_SEED !== 'true') {
    throw new Error(
      'Refusing to seed in production. Set ALLOW_PROD_SEED=true to override.',
    );
  }

  console.log('Seeding catalog taxonomy…');

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

  console.log('Seeding staff accounts…');
  for (const staff of staffUsers) {
    await prisma.user.upsert({
      where: { phone: staff.phone },
      update: { name: staff.name, role: staff.role, extraRoles: [] },
      create: {
        phone: staff.phone,
        name: staff.name,
        role: staff.role,
      },
    });
  }

  const categoryBySlug = Object.fromEntries(
    (await prisma.category.findMany()).map((c) => [c.slug, c.id]),
  );
  const brandBySlug = Object.fromEntries(
    (await prisma.brand.findMany()).map((b) => [b.slug, b.id]),
  );

  console.log('Seeding demo products…');
  for (const item of demoProducts) {
    const categoryId = categoryBySlug[item.categorySlug];
    if (!categoryId) continue;
    await prisma.product.upsert({
      where: { sku: item.sku },
      update: {
        name: item.name,
        slug: item.slug,
        price: item.price,
        inStock: true,
        isPopular: item.isPopular,
        categoryId,
        brandId: item.brandSlug ? brandBySlug[item.brandSlug] ?? null : null,
      },
      create: {
        name: item.name,
        slug: item.slug,
        sku: item.sku,
        price: item.price,
        inStock: true,
        isPopular: item.isPopular,
        categoryId,
        brandId: item.brandSlug ? brandBySlug[item.brandSlug] ?? null : null,
        description: 'Демо-товар для staging / TestFlight',
      },
    });
  }

  const products = await prisma.product.count();
  await applyTaxonomy(prisma);
  await seedDemoCatalog(prisma);
  console.log(`Ready. Products in DB: ${products}. Staff phones seeded.`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
