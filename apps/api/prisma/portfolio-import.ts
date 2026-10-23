/**
 * Portfolio import: uploads prepared renders to S3 (MinIO on the server) and upserts projects.
 *   npm run portfolio:import -- /path/to/portfolio_export
 * The folder holds manifest.json and <number>/<file>.jpg. Safe to re-run: images that are
 * already in the bucket with the same size are not uploaded again; a project's image list
 * is replaced by the one in the manifest. Projects missing from the manifest are left alone.
 */
import { readFileSync, statSync } from 'fs';
import { join } from 'path';
import {
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { PortfolioKind, PrismaClient } from '@prisma/client';

type ManifestImage = {
  file: string;
  room?: string | null;
  isPlan?: boolean;
  width?: number;
  height?: number;
};

type ManifestProject = {
  number: string;
  kind: PortfolioKind;
  title: string;
  objectType?: string | null;
  style?: string | null;
  area?: number | null;
  rooms?: string[];
  designer?: string | null;
  completedAt?: string | null;
  materialsCost?: number | null;
  description?: string | null;
  inRealization?: boolean;
  published?: boolean;
  sortOrder?: number;
  images: ManifestImage[];
};

type Manifest = {
  mosaic?: { number: string; file: string };
  styles: Array<{
    slug: string;
    label: string;
    cover?: { number: string; file: string };
  }>;
  projects: ManifestProject[];
};

const prisma = new PrismaClient();

function s3() {
  const endpoint = process.env.S3_ENDPOINT;
  const accessKeyId = process.env.S3_ACCESS_KEY;
  const secretAccessKey = process.env.S3_SECRET_KEY;
  if (!endpoint || !accessKeyId || !secretAccessKey) {
    throw new Error('S3_ENDPOINT, S3_ACCESS_KEY and S3_SECRET_KEY must be set');
  }
  return new S3Client({
    endpoint,
    region: process.env.S3_REGION ?? 'us-east-1',
    credentials: { accessKeyId, secretAccessKey },
    forcePathStyle: true,
  });
}

const keyOf = (number: string, file: string) => `portfolio/${number}/${file}`;

async function upload(
  client: S3Client,
  bucket: string,
  dir: string,
  number: string,
  file: string,
) {
  const path = join(dir, number, file);
  const size = statSync(path).size;
  const key = keyOf(number, file);
  try {
    const head = await client.send(
      new HeadObjectCommand({ Bucket: bucket, Key: key }),
    );
    if (head.ContentLength === size) return false;
  } catch {
    // Not there yet.
  }
  await client.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      Body: readFileSync(path),
      ContentType: file.endsWith('.png') ? 'image/png' : 'image/jpeg',
      CacheControl: 'public, max-age=31536000',
    }),
  );
  return true;
}

async function main() {
  const dir = process.argv[2];
  if (!dir)
    throw new Error(
      'Usage: npm run portfolio:import -- /path/to/portfolio_export',
    );
  const manifest = JSON.parse(
    readFileSync(join(dir, 'manifest.json'), 'utf8'),
  ) as Manifest;
  const client = s3();
  const bucket = process.env.S3_BUCKET ?? 'davart';

  let uploaded = 0;
  let order = 0;
  for (const style of manifest.styles) {
    order += 10;
    const coverKey = style.cover
      ? keyOf(style.cover.number, style.cover.file)
      : null;
    if (
      style.cover &&
      (await upload(client, bucket, dir, style.cover.number, style.cover.file))
    ) {
      uploaded += 1;
    }
    await prisma.portfolioStyle.upsert({
      where: { slug: style.slug },
      update: { label: style.label, coverKey, sortOrder: order },
      create: {
        slug: style.slug,
        label: style.label,
        coverKey,
        sortOrder: order,
      },
    });
  }

  if (manifest.mosaic) {
    // Always replaced: the grid is rebuilt on every export.
    const { number, file } = manifest.mosaic;
    await client.send(
      new PutObjectCommand({
        Bucket: bucket,
        Key: keyOf(number, file),
        Body: readFileSync(join(dir, number, file)),
        ContentType: 'image/jpeg',
        CacheControl: 'public, max-age=3600',
      }),
    );
    uploaded += 1;
  }

  for (const p of manifest.projects) {
    for (const image of p.images) {
      if (await upload(client, bucket, dir, p.number, image.file))
        uploaded += 1;
    }
    const data = {
      kind: p.kind,
      title: p.title,
      objectType: p.objectType ?? null,
      style: p.style ?? null,
      area: p.area ?? null,
      rooms: p.rooms ?? [],
      designer: p.designer ?? null,
      completedAt: p.completedAt ? new Date(p.completedAt) : null,
      materialsCost: p.materialsCost ?? null,
      description: p.description ?? null,
      inRealization: p.inRealization ?? false,
      published: p.published ?? false,
      sortOrder: p.sortOrder ?? 0,
    };
    const project = await prisma.portfolioProject.upsert({
      where: { number: p.number },
      update: data,
      create: { number: p.number, ...data },
    });
    await prisma.$transaction([
      prisma.portfolioImage.deleteMany({ where: { projectId: project.id } }),
      prisma.portfolioImage.createMany({
        data: p.images.map((image, index) => ({
          projectId: project.id,
          key: keyOf(p.number, image.file),
          room: image.room ?? null,
          isPlan: image.isPlan ?? false,
          width: image.width ?? null,
          height: image.height ?? null,
          sortOrder: index,
        })),
      }),
    ]);
  }
  console.log(
    `Portfolio: ${manifest.projects.length} projects, ${manifest.styles.length} styles, ${uploaded} files uploaded`,
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
