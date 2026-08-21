import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../src/app.module';
import { MeilisearchService } from '../src/meilisearch/meilisearch.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { RedisService } from '../src/redis/redis.service';

describe('Catalog Search (e2e)', () => {
  let app: INestApplication<App>;

  const productId = '550e8400-e29b-41d4-a716-446655440001';
  const categoryId = '550e8400-e29b-41d4-a716-446655440010';
  const brandId = '550e8400-e29b-41d4-a716-446655440020';

  const product = {
    id: productId,
    name: 'Белая плитка 60x60',
    slug: 'belaya-plitka',
    sku: 'DAV-00001',
    price: 4500,
    compareAtPrice: null,
    imageUrl: 'https://example.com/image.jpg',
    inStock: true,
    isPopular: true,
    description: 'Белая плитка для ванной',
    createdAt: new Date(),
    category: { id: categoryId, name: 'Плитка', slug: 'plitka' },
    brand: { id: brandId, name: 'Kerama Marazzi', slug: 'kerama-marazzi' },
    attributes: [
      { key: 'Материал', value: 'Керамика' },
      { key: 'Цвет', value: 'Белый' },
    ],
  };

  const mockPrismaService = {
    $connect: jest.fn(),
    $disconnect: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
    category: { findMany: jest.fn().mockResolvedValue([]) },
    brand: {
      findMany: jest.fn().mockResolvedValue([
        { id: brandId, name: 'Kerama Marazzi', slug: 'kerama-marazzi' },
      ]),
    },
    productAttribute: {
      findMany: jest.fn(async ({ where }: { where?: { key?: string } }) => {
        if (where?.key === 'Материал') return [{ value: 'Керамика' }];
        if (where?.key === 'Цвет') return [{ value: 'Белый' }];
        if (where?.key === 'Коллекция') {
          return [
            {
              value: 'Шарм Экстра',
              product: { collectionSlug: 'charme-extra' },
            },
          ];
        }
        return [];
      }),
    },
    product: {
      findMany: jest.fn().mockResolvedValue([product]),
      count: jest.fn().mockResolvedValue(1),
      findUnique: jest.fn(),
      aggregate: jest.fn().mockResolvedValue({
        _min: { price: 1500 },
        _max: { price: 30000 },
      }),
    },
  };

  const mockMeilisearchService = {
    indexProducts: jest.fn(),
    isAvailable: jest.fn().mockReturnValue(false),
    searchProductIds: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(PrismaService)
      .useValue(mockPrismaService)
      .overrideProvider(RedisService)
      .useValue({
        get: jest.fn(),
        set: jest.fn(),
        incr: jest.fn(),
        expire: jest.fn(),
        del: jest.fn(),
        ttl: jest.fn(),
      })
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

  it('GET /api/catalog/filters', async () => {
    const response = await request(app.getHttpServer())
      .get('/api/catalog/filters')
      .expect(200);

    expect(response.body.brands).toHaveLength(1);
    expect(response.body.materials).toContain('Керамика');
    expect(response.body.colors).toContain('Белый');
    expect(response.body.collections).toEqual([
      { slug: 'charme-extra', name: 'Шарм Экстра' },
    ]);
  });

  it('GET /api/catalog/search with query and price filter', async () => {
    const response = await request(app.getHttpServer())
      .get('/api/catalog/search')
      .query({ q: 'белая плитка', minPrice: 1000, maxPrice: 10000 })
      .expect(200);

    expect(response.body.items).toHaveLength(1);
    expect(response.body.items[0].name).toContain('Белая плитка');
  });

  it('GET /api/catalog/search with collection filter', async () => {
    const response = await request(app.getHttpServer())
      .get('/api/catalog/search')
      .query({ collection: 'charme-extra' })
      .expect(200);

    expect(response.body.items).toHaveLength(1);
    expect(mockPrismaService.product.findMany).toHaveBeenCalled();
  });

  it('GET /api/catalog/search with sort', async () => {
    await request(app.getHttpServer())
      .get('/api/catalog/search')
      .query({ sort: 'price_asc' })
      .expect(200);

    expect(mockPrismaService.product.findMany).toHaveBeenCalled();
  });
});
