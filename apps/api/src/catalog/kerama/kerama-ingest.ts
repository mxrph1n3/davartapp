import {
  CreateBucketCommand,
  HeadBucketCommand,
  PutBucketPolicyCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { PrismaClient } from '@prisma/client';
import {
  fetchKeramaProductDraft,
  fetchKeramaProductUrls,
  type KeramaProductDraft,
} from './kerama-parser';
import { demoCatalogPrice } from '../demo-price';

const BRAND = { name: 'Kerama Marazzi', slug: 'kerama-marazzi' };

export type KeramaIngestResult = {
  created: number;
  updated: number;
  total: number;
  imagesMirrored: number;
};

function skuCode(supplierSku: string): string {
  return supplierSku.replace(/^km-/, 'KM-');
}

function slugFor(supplierSku: string): string {
  return `kerama-${supplierSku.replace(/^km-/, '')}`;
}

function attributesOf(product: KeramaProductDraft) {
  const items = [
    { key: 'Материал', value: product.category.material },
    { key: 'Артикул', value: product.supplierSku.replace(/^km-/, '') },
  ];
  if (product.collectionName) {
    items.push({ key: 'Коллекция', value: product.collectionName });
  }
  if (product.size) {
    items.push({ key: 'Размеры', value: product.size });
  }
  return items;
}

function publicBaseUrl(endpoint: string, bucket: string): string {
  const fromEnv = process.env.S3_PUBLIC_BASE_URL?.replace(/\/$/, '');
  if (fromEnv) return fromEnv;
  return `${endpoint.replace(/\/$/, '')}/${bucket}`;
}

async function mapPool<T, R>(
  items: T[],
  concurrency: number,
  mapper: (item: T) => Promise<R>,
): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let next = 0;
  async function worker() {
    while (next < items.length) {
      const index = next;
      next += 1;
      results[index] = await mapper(items[index]);
    }
  }
  await Promise.all(
    Array.from(
      { length: Math.min(concurrency, Math.max(items.length, 1)) },
      () => worker(),
    ),
  );
  return results;
}

export async function mirrorKeramaImages(
  products: KeramaProductDraft[],
): Promise<{ products: KeramaProductDraft[]; mirrored: number }> {
  const endpoint = process.env.S3_ENDPOINT;
  const accessKey = process.env.S3_ACCESS_KEY;
  const secretKey = process.env.S3_SECRET_KEY;
  const bucket = process.env.S3_BUCKET ?? 'davart';
  const region = process.env.S3_REGION ?? 'us-east-1';

  if (!endpoint || !accessKey || !secretKey) {
    return { products, mirrored: 0 };
  }

  const client = new S3Client({
    endpoint,
    region,
    credentials: { accessKeyId: accessKey, secretAccessKey: secretKey },
    forcePathStyle: true,
  });

  try {
    try {
      await client.send(new HeadBucketCommand({ Bucket: bucket }));
    } catch {
      await client.send(new CreateBucketCommand({ Bucket: bucket }));
    }
    await client.send(
      new PutBucketPolicyCommand({
        Bucket: bucket,
        Policy: JSON.stringify({
          Version: '2012-10-17',
          Statement: [
            {
              Sid: 'PublicReadCatalog',
              Effect: 'Allow',
              Principal: { AWS: ['*'] },
              Action: ['s3:GetObject'],
              Resource: [`arn:aws:s3:::${bucket}/catalog/*`],
            },
          ],
        }),
      }),
    );
  } catch {
    return { products, mirrored: 0 };
  }

  const base = publicBaseUrl(endpoint, bucket);
  let mirrored = 0;
  const updated = await mapPool(products, 6, async (product) => {
    if (!product.imageUrl) return product;
    const ext = product.imageUrl.toLowerCase().includes('.png')
      ? 'png'
      : product.imageUrl.toLowerCase().includes('.webp')
        ? 'webp'
        : 'jpg';
    const key = `catalog/kerama/${product.supplierSku}.${ext}`;
    try {
      const response = await fetch(product.imageUrl, {
        headers: {
          'User-Agent':
            'Mozilla/5.0 (compatible; DavartCatalogIngest/1.0; +https://davart.app)',
          Accept: 'image/avif,image/webp,image/*,*/*',
        },
      });
      if (!response.ok) return product;
      const body = Buffer.from(await response.arrayBuffer());
      await client.send(
        new PutObjectCommand({
          Bucket: bucket,
          Key: key,
          Body: body,
          ContentType:
            ext === 'png'
              ? 'image/png'
              : ext === 'webp'
                ? 'image/webp'
                : 'image/jpeg',
          CacheControl: 'public, max-age=86400',
        }),
      );
      mirrored += 1;
      return { ...product, imageUrl: `${base}/${key}` };
    } catch {
      return product;
    }
  });

  return { products: updated, mirrored };
}

export async function ingestKeramaProducts(
  prisma: PrismaClient,
  products: KeramaProductDraft[],
): Promise<KeramaIngestResult> {
  const brand = await prisma.brand.upsert({
    where: { slug: BRAND.slug },
    update: { name: BRAND.name },
    create: BRAND,
  });

  const mirrored = await mirrorKeramaImages(products);
  const catalog = mirrored.products;

  const categoryIds = new Map<string, string>();
  const uniqueCategories = [
    ...new Map(
      catalog.map((product) => [product.category.slug, product.category]),
    ).values(),
  ];
  for (const category of uniqueCategories) {
    const saved = await prisma.category.upsert({
      where: { slug: category.slug },
      update: { name: category.name, sortOrder: category.sortOrder },
      create: {
        name: category.name,
        slug: category.slug,
        sortOrder: category.sortOrder,
      },
    });
    categoryIds.set(category.slug, saved.id);
  }

  let created = 0;
  let updated = 0;

  for (const product of catalog) {
    const categoryId = categoryIds.get(product.category.slug);
    if (!categoryId) continue;

    const collectionBit = product.collectionName
      ? `, коллекция «${product.collectionName}»`
      : '';
    const article = product.supplierSku.replace(/^km-/, '');
    const description = `${product.category.name} Kerama Marazzi${collectionBit}. Артикул ${article}.`;

    const existing = await prisma.product.findUnique({
      where: { supplierSku: product.supplierSku },
      select: { id: true },
    });

    const data = {
      name: product.name,
      slug: slugFor(product.supplierSku),
      sku: skuCode(product.supplierSku),
      supplierSku: product.supplierSku,
      collectionSlug: product.collectionSlug,
      sourceUrl: product.sourceUrl,
      description,
      price:
        product.price > 0
          ? product.price
          : demoCatalogPrice(
              skuCode(product.supplierSku),
              product.category.slug,
            ),
      imageUrl: product.imageUrl || null,
      inStock: product.inStock,
      categoryId,
      brandId: brand.id,
    };

    const saved = existing
      ? await prisma.product.update({ where: { id: existing.id }, data })
      : await prisma.product.create({ data });

    if (existing) updated += 1;
    else created += 1;

    await prisma.productAttribute.deleteMany({
      where: { productId: saved.id },
    });
    await prisma.productAttribute.createMany({
      data: attributesOf(product).map((item) => ({
        ...item,
        productId: saved.id,
      })),
    });
  }

  return {
    created,
    updated,
    total: catalog.length,
    imagesMirrored: mirrored.mirrored,
  };
}

export async function ingestKeramaFromSitemap(
  prisma: PrismaClient,
  options?: { limit?: number; batchSize?: number },
): Promise<KeramaIngestResult> {
  const urls = await fetchKeramaProductUrls({ limit: options?.limit });
  const batchSize = options?.batchSize ?? 40;
  const totals: KeramaIngestResult = {
    created: 0,
    updated: 0,
    total: 0,
    imagesMirrored: 0,
  };

  for (let offset = 0; offset < urls.length; offset += batchSize) {
    const slice = urls.slice(offset, offset + batchSize);
    const drafts: KeramaProductDraft[] = [];
    for (let i = 0; i < slice.length; i += 3) {
      const group = slice.slice(i, i + 3);
      const parsed = await Promise.all(
        group.map(async (url) => {
          try {
            return await fetchKeramaProductDraft(url);
          } catch (error) {
            console.warn(
              `Skip ${url}: ${error instanceof Error ? error.message : error}`,
            );
            return null;
          }
        }),
      );
      for (const item of parsed) {
        if (item) drafts.push(item);
      }
      await new Promise((resolve) => setTimeout(resolve, 180));
    }

    if (drafts.length === 0) continue;
    const result = await ingestKeramaProducts(prisma, drafts);
    totals.created += result.created;
    totals.updated += result.updated;
    totals.total += result.total;
    totals.imagesMirrored += result.imagesMirrored;
    console.log(
      `Kerama ingest ${Math.min(offset + batchSize, urls.length)}/${urls.length} ` +
        `created=${totals.created} updated=${totals.updated} images=${totals.imagesMirrored}`,
    );
  }

  return totals;
}
