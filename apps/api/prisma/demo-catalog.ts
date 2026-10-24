/**
 * Dev/staging demo data for the new catalog: packs in м², characteristics, collections.
 * Not for production — real goods come from manufacturers' sites.
 */
import { PrismaClient } from '@prisma/client';

type Demo = {
  sku: string; name: string; sub: string; brand?: string; price: number; collection?: string;
  unit?: string; pack?: [number, number]; inStock?: boolean; lead?: [number, number];
  attrs: Record<string, string>;
};

const DEMO: Demo[] = [
  { sku: 'DEMO-KG-101', name: 'Керамогранит Calacatta Lux полированный 60×120', sub: 'keramogranit', brand: 'italon', price: 3450, collection: 'charme-evo', unit: 'м²', pack: [1.44, 2], attrs: { Размер: '60×120', Поверхность: 'Полированная', Толщина: '9 мм', Применение: 'Пол и стены', Цвет: 'Белый' } },
  { sku: 'DEMO-KG-102', name: 'Керамогранит Calacatta Lux 60×60', sub: 'keramogranit', brand: 'italon', price: 3120, collection: 'charme-evo', unit: 'м²', pack: [1.44, 4], attrs: { Размер: '60×60', Поверхность: 'Полированная', Толщина: '9 мм', Применение: 'Пол и стены', Цвет: 'Белый' } },
  { sku: 'DEMO-KG-103', name: 'Керамогранит Cemento Grigio 60×60', sub: 'keramogranit', brand: 'kerama-marazzi', price: 1290, unit: 'м²', pack: [1.44, 4], attrs: { Размер: '60×60', Поверхность: 'Матовая', Толщина: '9 мм', Применение: 'Пол и стены', Цвет: 'Серый' } },
  { sku: 'DEMO-KG-104', name: 'Керамогранит Травертин лаппатированный 60×120', sub: 'keramogranit', brand: 'kerama-marazzi', price: 2890, unit: 'м²', pack: [1.44, 2], inStock: false, lead: [7, 10], attrs: { Размер: '60×120', Поверхность: 'Лаппатированная', Толщина: '11 мм', Применение: 'Пол и стены', Цвет: 'Бежевый' } },
  { sku: 'DEMO-KG-105', name: 'Керамогранит Element Wood Rovere 20×120', sub: 'keramogranit', brand: 'italon', price: 2140, unit: 'м²', pack: [1.2, 5], attrs: { Размер: '20×120', Поверхность: 'Структурированная', Толщина: '9 мм', Применение: 'Пол', Цвет: 'Бежевый' } },
  { sku: 'DEMO-KV-201', name: 'Кварцвинил Alpine Floor Дуб Натуральный', sub: 'kvarcvinil', price: 2290, unit: 'м²', pack: [2.2, 10], attrs: { Размер: '1220×183 мм', Толщина: '4 мм', 'Класс износа': '43', Цвет: 'Бежевый' } },
  { sku: 'DEMO-DV-301', name: 'Дверь скрытого монтажа под покраску 2000×800', sub: 'dveri-skrytye', price: 18900, attrs: { Размер: '2000×800', Открывание: 'Внутрь' } },
  { sku: 'DEMO-SV-401', name: 'Подвесной светильник шар 300 мм, латунь', sub: 'lyustry', price: 12400, attrs: { Цвет: 'Латунь', Цоколь: 'E27' } },
];

export async function seedDemoCatalog(prisma: PrismaClient) {
  const cats = Object.fromEntries((await prisma.category.findMany()).map((c) => [c.slug, c.id]));
  const brands = Object.fromEntries((await prisma.brand.findMany()).map((b) => [b.slug, b.id]));
  for (const d of DEMO) {
    const categoryId = cats[d.sub];
    if (!categoryId) continue;
    const data = {
      name: d.name,
      slug: d.sku.toLowerCase(),
      price: d.price,
      categoryId,
      brandId: d.brand ? brands[d.brand] ?? null : null,
      collectionSlug: d.collection ?? null,
      unit: d.unit ?? 'шт',
      sellByPack: !!d.pack,
      packSize: d.pack?.[0] ?? null,
      packPieces: d.pack?.[1] ?? null,
      inStock: d.inStock ?? true,
      leadTimeMinDays: d.lead?.[0] ?? null,
      leadTimeMaxDays: d.lead?.[1] ?? null,
      description: 'Демо-товар для проверки каталога.',
    };
    const product = await prisma.product.upsert({ where: { sku: d.sku }, update: data, create: { sku: d.sku, ...data } });
    await prisma.productAttribute.deleteMany({ where: { productId: product.id } });
    await prisma.productAttribute.createMany({
      data: Object.entries(d.attrs).map(([key, value]) => ({ key, value, productId: product.id })),
    });
  }
}
