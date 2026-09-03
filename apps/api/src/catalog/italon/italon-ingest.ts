import {
  CreateBucketCommand,
  HeadBucketCommand,
  PutBucketPolicyCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { PrismaClient } from '@prisma/client';
import type { ItalonProductDraft } from './italon-parser';
import { demoCatalogPrice } from '../demo-price';

const BRAND = { name: 'Italon', slug: 'italon' };

export type ItalonIngestResult = {
  created: number;
  updated: number;
  total: number;
  imagesMirrored: number;
};

function skuCode(supplierSku: string): string {
  return `ITL-${supplierSku}`;
}

function slugFor(supplierSku: string): string {
  return `italon-${supplierSku}`;
}

function attributesOf(product: ItalonProductDraft) {
  const items = [
    { key: 'Материал', value: product.category.material },
    { key: 'Артикул', value: product.supplierSku },
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
  mapper: (item: T, index: number) => Promise<R>,
): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let next = 0;

  async function worker() {
    while (next < items.length) {
      const index = next;
      next += 1;
      results[index] = await mapper(items[index], index);
    }
  }

  const workers = Array.from(
    { length: Math.min(concurrency, Math.max(items.length, 1)) },
    () => worker(),
  );
  await Promise.all(workers);
  return results;
}

export async function mirrorItalonImages(
  products: ItalonProductDraft[],
): Promise<{ products: ItalonProductDraft[]; mirrored: number }> {
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

  const updated = await mapPool(products, 8, async (product) => {
    const ext = product.imageUrl.toLowerCase().includes('.png') ? 'png' : 'jpg';
    const key = `catalog/italon/${product.supplierSku}.${ext}`;
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
          ContentType: ext === 'png' ? 'image/png' : 'image/jpeg',
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

export async function ingestItalonProducts(
  prisma: PrismaClient,
  products: ItalonProductDraft[],
): Promise<ItalonIngestResult> {
  const brand = await prisma.brand.upsert({
    where: { slug: BRAND.slug },
    update: { name: BRAND.name },
    create: BRAND,
  });

  const mirrored = await mirrorItalonImages(products);
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
    const sku = skuCode(product.supplierSku);
    const slug = slugFor(product.supplierSku);
    const categoryId = categoryIds.get(product.category.slug);
    if (!categoryId) continue;

    const collectionBit = product.collectionName
      ? `, коллекция «${product.collectionName}»`
      : '';
    const description = `${product.category.name} Italon${collectionBit}. Артикул ${product.supplierSku}.`;

    const existing = await prisma.product.findUnique({
      where: { supplierSku: product.supplierSku },
      select: { id: true },
    });

    const data = {
      name: product.name,
      slug,
      sku,
      supplierSku: product.supplierSku,
      collectionSlug: product.collectionSlug,
      sourceUrl: product.sourceUrl,
      description,
      price: demoCatalogPrice(sku, product.category.slug),
      imageUrl: product.imageUrl,
      inStock: true,
      categoryId,
      brandId: brand.id,
    };

    const saved = existing
      ? await prisma.product.update({
          where: { id: existing.id },
          data,
        })
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
