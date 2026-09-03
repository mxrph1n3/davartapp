import { matchItalonCollection } from './italon-collections';
import { classifyRuListing, parseItalonImageSitemap } from './italon-parser';

describe('Italon parser', () => {
  it('matches longest collection alias', () => {
    expect(matchItalonCollection('Шарм Экстра Силвер 60x120 CM')?.slug).toBe(
      'charme-extra',
    );
    expect(matchItalonCollection('Шарм Эво Уайт 30x60')?.slug).toBe(
      'sharm-evo',
    );
    expect(matchItalonCollection('Шампейн 30x120 CM')).toBeNull();
  });

  it('classifies RU catalog listings and ignores IT/EN and dealers', () => {
    expect(
      classifyRuListing(
        'https://www.italonceramica.ru/ru/kollektsii/keramogranit/',
      )?.category.slug,
    ).toBe('keramogranit');
    expect(
      classifyRuListing(
        'https://www.italonceramica.ru/ru/kollektsii/nastennayaplitka/',
      )?.category.slug,
    ).toBe('nastennaya-plitka');
    expect(
      classifyRuListing('https://www.italonceramica.ru/it/prodotti/pavimenti/'),
    ).toBeNull();
    expect(
      classifyRuListing('https://www.italonceramica.ru/ru/dealer/rossiya/'),
    ).toBeNull();
  });

  it('parses RU catalog SKUs and prefers keramogranit over collection pages', () => {
    const xml = `<?xml version="1.0"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">
  <url>
    <loc>https://www.italonceramica.ru/ru/kollektsii/charme-extra/silver/</loc>
    <image:image>
      <image:loc>https://file.italonceramica.ru/96x96/sitodacodificaarticoli/articoli/610010000815.jpg</image:loc>
      <image:title>Charme Extra Silver</image:title>
    </image:image>
  </url>
  <url>
    <loc>https://www.italonceramica.ru/ru/kollektsii/keramogranit/</loc>
    <image:image>
      <image:loc>https://file.italonceramica.ru/96x384/sitodacodificaarticoli/articoli/610010000815.jpg</image:loc>
      <image:title>Шарм Экстра Силвер 60x120 CM</image:title>
    </image:image>
    <image:image>
      <image:loc>https://file.italonceramica.ru/96x96/sitodacodificaarticoli/articoli/600010002278.jpg</image:loc>
      <image:title>Плэй Вуд 30x30 CM</image:title>
    </image:image>
  </url>
  <url>
    <loc>https://www.italonceramica.ru/ru/kollektsii/nastennayaplitka/</loc>
    <image:image>
      <image:loc>https://file.italonceramica.ru/96x96/sitodacodificaarticoli/articoli/700010000001.jpg</image:loc>
      <image:title>Шарм Уолл 30x90 CM</image:title>
    </image:image>
  </url>
  <url>
    <loc>https://www.italonceramica.ru/it/prodotti/pavimenti/</loc>
    <image:image>
      <image:loc>https://file.italonceramica.ru/sitodacodificaarticoli/articoli/999.jpg</image:loc>
      <image:title>Ignore IT</image:title>
    </image:image>
  </url>
</urlset>`;

    const products = parseItalonImageSitemap(xml);
    expect(products).toHaveLength(3);

    const extra = products.find((item) => item.supplierSku === '610010000815');
    expect(extra).toMatchObject({
      collectionSlug: 'charme-extra',
      collectionName: 'Шарм Экстра',
      size: '60×120 см',
      sourceUrl: 'https://www.italonceramica.ru/ru/kollektsii/keramogranit/',
      category: { slug: 'keramogranit' },
    });
    expect(extra?.imageUrl).toContain('600x600');
    expect(extra?.name).toContain('Шарм');

    const wall = products.find((item) => item.supplierSku === '700010000001');
    expect(wall?.category.slug).toBe('nastennaya-plitka');
    expect(products.find((item) => item.supplierSku === '999')).toBeUndefined();
  });
});
