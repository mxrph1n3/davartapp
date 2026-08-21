import {
  categoryFromPath,
  normalizeKeramaImage,
  parseKeramaProductHtml,
  parseKeramaProductUrls,
  sanitizeKeramaSku,
} from './kerama-parser';

describe('Kerama parser', () => {
  it('maps catalog path to category', () => {
    expect(categoryFromPath('/catalog/gres/65011/').slug).toBe('keramogranit');
    expect(categoryFromPath('/catalog/ceramic_tile/op_a170_65000/').slug).toBe(
      'nastennaya-plitka',
    );
    expect(categoryFromPath('/catalog/sinks/bg_wb_100/').slug).toBe(
      'santehnika',
    );
    expect(categoryFromPath('/news/event/hello/')).toBeNull();
  });

  it('fixes truncated Kerama image hosts', () => {
    expect(
      normalizeKeramaImage(
        'https://kerama-marazzi/upload/iblock/8df/tile.webp',
      ),
    ).toBe('https://kerama-marazzi.com/upload/iblock/8df/tile.webp');
    expect(normalizeKeramaImage('/upload/iblock/a.webp')).toBe(
      'https://kerama-marazzi.com/upload/iblock/a.webp',
    );
  });

  it('sanitizes JSON-LD SKUs with backslashes', () => {
    expect(sanitizeKeramaSku('OP\\A170\\65000')).toBe('OP-A170-65000');
  });

  it('keeps only product URLs from sitemap', () => {
    const xml = `<?xml version="1.0"?>
<urlset>
  <loc>https://kerama-marazzi.com/catalog/gres/65011/</loc>
  <loc>https://kerama-marazzi.com/catalog/gres/</loc>
  <loc>https://kerama-marazzi.com/news/event/foo/</loc>
  <loc>https://kerama-marazzi.com/catalog/ceramic_tile/op_a170_65000/</loc>
</urlset>`;
    expect(parseKeramaProductUrls(xml)).toEqual([
      'https://kerama-marazzi.com/catalog/gres/65011/',
      'https://kerama-marazzi.com/catalog/ceramic_tile/op_a170_65000/',
    ]);
  });

  it('parses Product JSON-LD and series breadcrumb', () => {
    const html = `
<script type="application/ld+json">{"@type":"Product","name":"Арабески Майолика серый светлый глянцевый 26x30x0,7","sku":"65011","image":"https://kerama-marazzi/upload/iblock/8df/tile.webp","offers":{"@type":"Offer","availability":"https://schema.org/InStock","price":"1234"},"category":"Керамический гранит"}</script>
<script type="application/ld+json">{"@type":"BreadcrumbList","itemListElement":[{"@type":"ListItem","position":4,"name":"Арабески Майолика","item":"https://kerama-marazzi.com/catalog/series/gres/arabesques_majolica/"}]}</script>
`;
    const product = parseKeramaProductHtml(
      html,
      'https://kerama-marazzi.com/catalog/gres/65011/',
    );
    expect(product).toMatchObject({
      supplierSku: 'km-65011',
      collectionName: 'Арабески Майолика',
      collectionSlug: 'arabesques-majolica',
      size: '26×30×0.7 см',
      inStock: true,
      price: 1234,
      category: { slug: 'keramogranit' },
    });
    expect(product?.imageUrl).toContain('kerama-marazzi.com/upload');
  });
});
