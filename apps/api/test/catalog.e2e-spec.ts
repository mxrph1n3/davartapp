import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../src/app.module';
import { MeilisearchService } from '../src/meilisearch/meilisearch.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { RedisService } from '../src/redis/redis.service';

describe('Catalog (e2e)', () => {
  let app: INestApplication<App>;

  const category = {
    id: 'cat-1',
    name: 'Мебель',
    slug: 'mebel',
    imageUrl: null,
    sortOrder: 1,
    _count: { products: 1 },
  };

  const productId = '550e8400-e29b-41d4-a716-446655440001';

  const product = {
    id: productId,
    name: 'Диван сканди',
    slug: 'divan-skandi',
    sku: 'DAV-00001',
    price: 45000,
    compareAtPrice: null,
    imageUrl: 'https://example.com/image.jpg',
    inStock: true,
    isPopular: true,
    description: 'Удобный диван',
    createdAt: new Date(),
    category: { id: 'cat-1', name: 'Мебель', slug: 'mebel' },
    brand: { id: 'brand-1', name: 'IKEA', slug: 'ikea' },
    attributes: [{ key: 'Материал', value: 'Ткань' }],
  };

  const mockPrismaService = {
    $connect: jest.fn(),
    $disconnect: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
    category: {
      findMany: jest.fn().mockResolvedValue([category]),
    },
    product: {
      findMany: jest.fn().mockResolvedValue([product]),
      count: jest.fn().mockResolvedValue(1),
      findUnique: jest.fn().mockResolvedValue(product),
    },
  };

  const mockRedisService = {
    get: jest.fn(),
    set: jest.fn(),
    incr: jest.fn(),
    expire: jest.fn(),
    del: jest.fn(),
    ttl: jest.fn(),
  };

  const mockMeilisearchService = {
    indexProducts: jest.fn(),
    isAvailable: jest.fn().mockReturnValue(false),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(PrismaService)
      .useValue(mockPrismaService)
      .overrideProvider(RedisService)
      .useValue(mockRedisService)
      .overrideProvider(MeilisearchService)
      .useValue(mockMeilisearchService)
      .compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('api');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    await app.init();
  });

  afterEach(async () => {
    await app.close();
  });

  it('GET /api/catalog/categories', async () => {
    const response = await request(app.getHttpServer())
      .get('/api/catalog/categories')
      .expect(200);

    expect(response.body).toHaveLength(1);
    expect(response.body[0].name).toBe('Мебель');
  });

  it('GET /api/catalog/products', async () => {
    const response = await request(app.getHttpServer())
      .get('/api/catalog/products')
      .expect(200);

    expect(response.body.items).toHaveLength(1);
    expect(response.body.pagination.total).toBe(1);
  });

  it('GET /api/catalog/products/:id', async () => {
    const response = await request(app.getHttpServer())
      .get(`/api/catalog/products/${productId}`)
      .expect(200);

    expect(response.body.name).toBe('Диван сканди');
    expect(response.body.attributes).toHaveLength(1);
  });

  it('POST /api/catalog/reindex denied without ALLOW_DEV_ENDPOINTS', async () => {
    const previous = process.env.ALLOW_DEV_ENDPOINTS;
    process.env.ALLOW_DEV_ENDPOINTS = 'false';

    await request(app.getHttpServer())
      .post('/api/catalog/reindex')
      .expect(403);

    process.env.ALLOW_DEV_ENDPOINTS = previous;
  });

  it('POST /api/catalog/reindex when ALLOW_DEV_ENDPOINTS=true', async () => {
    mockPrismaService.product.findMany.mockResolvedValueOnce([]);

    const response = await request(app.getHttpServer())
      .post('/api/catalog/reindex')
      .expect(200);

    expect(response.body.indexed).toBe(0);
  });
});
