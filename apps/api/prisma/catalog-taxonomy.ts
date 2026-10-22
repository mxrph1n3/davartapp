/**
 * Shop taxonomy: 14 top-level tiles and their subcategories (approved by the studio, Oct 2026).
 * Idempotent — safe to run on staging/production after `prisma migrate deploy`:
 *   npm run catalog:taxonomy
 * Existing categories (keramogranit, nastennaya-plitka, mebel, santehnika, oboi, …) keep their
 * ids and products; they only get a parent.
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

type Node = { slug: string; name: string; children?: Array<{ slug: string; name: string }> };

// Order = order of tiles on the shop home (3 per row). «Весь каталог» is not a category.
export const TAXONOMY: Node[] = [
  {
    slug: 'napolnye-pokrytiya',
    name: 'Напольные покрытия',
    children: [
      { slug: 'kvarcvinil', name: 'Кварцвинил' },
      { slug: 'laminat', name: 'Ламинат' },
      { slug: 'parket', name: 'Паркет и инженерная доска' },
      { slug: 'plintus-napolnyj', name: 'Плинтус напольный' },
      { slug: 'podlozhka', name: 'Подложка' },
    ],
  },
  {
    slug: 'plitka-i-keramogranit',
    name: 'Плитка и керамогранит',
    children: [
      { slug: 'keramogranit', name: 'Керамогранит' },
      { slug: 'nastennaya-plitka', name: 'Настенная плитка' },
      { slug: 'strukturirovannaya-plitka', name: 'Структурированная плитка' },
      { slug: 'mozaika', name: 'Мозаика' },
      { slug: 'klej-i-zatirka', name: 'Клей и затирка' },
    ],
  },
  {
    slug: 'santehnika',
    name: 'Сантехника',
    children: [
      { slug: 'rakoviny', name: 'Раковины' },
      { slug: 'unitazy', name: 'Унитазы и инсталляции' },
      { slug: 'vanny', name: 'Ванны' },
      { slug: 'dushevye', name: 'Душевые' },
      { slug: 'smesiteli', name: 'Смесители' },
      { slug: 'polotencesushiteli', name: 'Полотенцесушители' },
      { slug: 'mebel-dlya-vannoj', name: 'Мебель для ванной' },
    ],
  },
  {
    slug: 'steny',
    name: 'Стены',
    children: [
      { slug: 'kraski', name: 'Краски' },
      { slug: 'dekorativnaya-shtukaturka', name: 'Декоративная штукатурка' },
      { slug: 'oboi', name: 'Обои' },
      { slug: 'stenovye-paneli', name: 'Стеновые панели' },
      { slug: 'lepnina-i-moldingi', name: 'Лепнина и молдинги' },
      { slug: 'karnizy-potolochnye', name: 'Карнизы потолочные' },
    ],
  },
  {
    slug: 'dveri',
    name: 'Двери',
    children: [
      { slug: 'dveri-mezhkomnatnye', name: 'Межкомнатные двери' },
      { slug: 'dveri-skrytye', name: 'Скрытые двери' },
      { slug: 'dveri-vhodnye', name: 'Входные двери' },
      { slug: 'dvernaya-furnitura', name: 'Дверная фурнитура' },
    ],
  },
  {
    slug: 'svet-i-elektrika',
    name: 'Свет и электрика',
    children: [
      { slug: 'lyustry', name: 'Люстры и подвесы' },
      { slug: 'vstraivaemye-svetilniki', name: 'Встраиваемые светильники' },
      { slug: 'trekovye-svetilniki', name: 'Трековые светильники' },
      { slug: 'bra-i-torshery', name: 'Бра и торшеры' },
      { slug: 'podsvetka', name: 'Подсветка' },
      { slug: 'rozetki-i-vyklyuchateli', name: 'Розетки и выключатели' },
    ],
  },
  {
    slug: 'kondicionery-i-otoplenie',
    name: 'Кондиционеры и отопление',
    children: [
      { slug: 'kondicionery', name: 'Кондиционеры' },
      { slug: 'radiatory', name: 'Радиаторы' },
      { slug: 'teplyj-pol', name: 'Тёплый пол' },
      { slug: 'kaminy', name: 'Камины' },
    ],
  },
  {
    slug: 'mebel',
    name: 'Мебель',
    children: [
      { slug: 'divany', name: 'Диваны' },
      { slug: 'kresla', name: 'Кресла' },
      { slug: 'krovati', name: 'Кровати' },
      { slug: 'stoly', name: 'Столы' },
      { slug: 'stulya', name: 'Стулья' },
    ],
  },
  {
    slug: 'korpusnaya-mebel',
    name: 'Корпусная мебель',
    children: [
      { slug: 'kuhni', name: 'Кухни на заказ' },
      { slug: 'shkafy', name: 'Шкафы' },
      { slug: 'garderobnye', name: 'Гардеробные' },
      { slug: 'sistemy-hraneniya', name: 'Системы хранения' },
    ],
  },
  {
    slug: 'bytovaya-tehnika',
    name: 'Бытовая техника',
    children: [
      { slug: 'duhovye-shkafy', name: 'Духовые шкафы' },
      { slug: 'varochnye-paneli', name: 'Варочные панели' },
      { slug: 'holodilniki', name: 'Холодильники' },
      { slug: 'posudomoechnye', name: 'Посудомоечные машины' },
      { slug: 'vytyazhki', name: 'Вытяжки' },
      { slug: 'kuhonnye-mojki', name: 'Кухонные мойки и смесители' },
    ],
  },
  {
    slug: 'dekor-i-tekstil',
    name: 'Декор и текстиль',
    children: [
      { slug: 'shtory', name: 'Шторы и карнизы' },
      { slug: 'kovry', name: 'Ковры' },
      { slug: 'zerkala', name: 'Зеркала' },
      { slug: 'kartiny', name: 'Картины и постеры' },
    ],
  },
  { slug: 'okna', name: 'Окна' },
  { slug: 'potolki', name: 'Потолки', children: [{ slug: 'natyazhnye-potolki', name: 'Натяжные потолки' }] },
];

export async function applyTaxonomy(client: PrismaClient = prisma) {
  let order = 0;
  for (const top of TAXONOMY) {
    order += 10;
    const parent = await client.category.upsert({
      where: { slug: top.slug },
      update: { name: top.name, sortOrder: order, parentId: null },
      create: { slug: top.slug, name: top.name, sortOrder: order },
    });
    let childOrder = 0;
    for (const child of top.children ?? []) {
      childOrder += 1;
      await client.category.upsert({
        where: { slug: child.slug },
        update: { name: child.name, sortOrder: childOrder, parentId: parent.id },
        create: { slug: child.slug, name: child.name, sortOrder: childOrder, parentId: parent.id },
      });
    }
  }
}

if (require.main === module) {
  applyTaxonomy()
    .then(() => console.log('Taxonomy applied:', TAXONOMY.length, 'top-level categories'))
    .catch((e) => {
      console.error(e);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
