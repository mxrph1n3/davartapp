import {
  CreateBucketCommand,
  HeadBucketCommand,
  PutBucketPolicyCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';

/** Curated Unsplash crops — verified 200 OK pools per category slug. */
export const thematicImageSources: Record<string, string[]> = {
  mebel: [
    'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1567538096630-e0c55bd6374c?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1592078615290-033ee584e267?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1493666438817-866a91353ca9?auto=format&fit=crop&w=800&h=800',
  ],
  osveshchenie: [
    'https://images.unsplash.com/photo-1513506003901-1e6a229e2d15?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1507473885765-e6ed057f782c?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?auto=format&fit=crop&w=800&h=800',
  ],
  santehnika: [
    'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1552321554-5fefe8c9ef14?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1600566752355-35792bedcfea?auto=format&fit=crop&w=800&h=800',
  ],
  plitka: [
    'https://images.unsplash.com/photo-1600607686527-6fb886090705?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1631679706909-1844bbd07221?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1618220179428-22790b461013?auto=format&fit=crop&w=800&h=800',
  ],
  'napolnye-pokrytiya': [
    'https://images.unsplash.com/photo-1616486338812-3dadae4b4ace?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1615874959474-d609969a20ed?auto=format&fit=crop&w=800&h=800',
  ],
  kraski: [
    'https://images.unsplash.com/photo-1562259949-e8e7689d7828?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1484154218962-a197022b5858?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=800&h=800',
  ],
  dveri: [
    'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?auto=format&fit=crop&w=800&h=800',
  ],
  okna: [
    'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1493809842364-78817add7ffb?auto=format&fit=crop&w=800&h=800',
  ],
  dekor: [
    'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1616046229478-9901c5536a45?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=800&h=800',
  ],
  tekstil: [
    'https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1540518614846-7eded433c457?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1615529328331-f8917597711f?auto=format&fit=crop&w=800&h=800',
  ],
  elektrika: [
    'https://images.unsplash.com/photo-1558002038-1055907df827?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?auto=format&fit=crop&w=800&h=800',
  ],
  'stroitelnye-materialy': [
    'https://images.unsplash.com/photo-1504307651254-35680f356dfd?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1581094794329-c8112a89af12?auto=format&fit=crop&w=800&h=800',
    'https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=800&h=800',
  ],
};

export type ProductImageStore = {
  urlFor(categorySlug: string, productIndex: number): string;
  prepare(): Promise<{ mode: 'minio' | 'remote-fallback'; uploaded: number }>;
};

function publicBaseUrl(endpoint: string, bucket: string): string {
  const fromEnv = process.env.S3_PUBLIC_BASE_URL?.replace(/\/$/, '');
  if (fromEnv) return fromEnv;
  return `${endpoint.replace(/\/$/, '')}/${bucket}`;
}

function pickSource(categorySlug: string, productIndex: number): string {
  const pool = thematicImageSources[categorySlug] ?? thematicImageSources.mebel;
  return pool[(productIndex - 1) % pool.length];
}

async function download(url: string): Promise<Buffer> {
  const response = await fetch(url, {
    headers: { 'User-Agent': 'davart-seed/1.0' },
  });
  if (!response.ok) {
    throw new Error(`Failed to download ${url}: ${response.status}`);
  }
  return Buffer.from(await response.arrayBuffer());
}

export function createProductImageStore(): ProductImageStore {
  const endpoint = process.env.S3_ENDPOINT;
  const accessKey = process.env.S3_ACCESS_KEY;
  const secretKey = process.env.S3_SECRET_KEY;
  const bucket = process.env.S3_BUCKET ?? 'davart';
  const region = process.env.S3_REGION ?? 'us-east-1';

  const keyToPublicUrl = new Map<string, string>();
  const downloadCache = new Map<string, Buffer>();

  function storageKey(categorySlug: string, poolIndex: number): string {
    return `catalog/${categorySlug}/${poolIndex + 1}.jpg`;
  }

  async function ensureBucket(client: S3Client) {
    try {
      await client.send(new HeadBucketCommand({ Bucket: bucket }));
    } catch {
      await client.send(new CreateBucketCommand({ Bucket: bucket }));
    }

    const policy = {
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
    };

    await client.send(
      new PutBucketPolicyCommand({
        Bucket: bucket,
        Policy: JSON.stringify(policy),
      }),
    );
  }

  return {
    urlFor(categorySlug: string, productIndex: number): string {
      const pool = thematicImageSources[categorySlug] ?? thematicImageSources.mebel;
      const poolIndex = (productIndex - 1) % pool.length;
      const key = storageKey(categorySlug, poolIndex);
      return keyToPublicUrl.get(key) ?? pickSource(categorySlug, productIndex);
    },

    async prepare() {
      if (!endpoint || !accessKey || !secretKey) {
        console.warn(
          'S3 not configured — product images will use remote Unsplash URLs',
        );
        return { mode: 'remote-fallback' as const, uploaded: 0 };
      }

      const client = new S3Client({
        endpoint,
        region,
        credentials: { accessKeyId: accessKey, secretAccessKey: secretKey },
        forcePathStyle: true,
      });

      try {
        await ensureBucket(client);
      } catch (error) {
        console.warn(`MinIO unavailable (${error}) — using remote Unsplash URLs`);
        return { mode: 'remote-fallback' as const, uploaded: 0 };
      }

      const base = publicBaseUrl(endpoint, bucket);
      let uploaded = 0;

      for (const [slug, sources] of Object.entries(thematicImageSources)) {
        for (let i = 0; i < sources.length; i += 1) {
          const source = sources[i];
          const key = storageKey(slug, i);

          let body = downloadCache.get(source);
          if (!body) {
            try {
              body = await download(source);
              downloadCache.set(source, body);
            } catch (error) {
              console.warn(`Skip ${key}: ${error}`);
              keyToPublicUrl.set(key, source);
              continue;
            }
          }

          await client.send(
            new PutObjectCommand({
              Bucket: bucket,
              Key: key,
              Body: body,
              ContentType: 'image/jpeg',
              CacheControl: 'public, max-age=86400',
            }),
          );
          keyToPublicUrl.set(key, `${base}/${key}`);
          uploaded += 1;
        }
      }

      console.log(
        `Uploaded ${uploaded} thematic catalog images to MinIO (${base}/catalog/…)`,
      );
      return { mode: 'minio' as const, uploaded };
    },
  };
}
