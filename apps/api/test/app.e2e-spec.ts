import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../src/app.module';
import { MeilisearchService } from '../src/meilisearch/meilisearch.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { RedisService } from '../src/redis/redis.service';

describe('Health (e2e)', () => {
  let app: INestApplication<App>;

  const mockPrismaService = {
    $connect: jest.fn(),
    $disconnect: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
  };

  const mockRedisService = {
    ping: jest.fn(async () => true),
  };

  const mockMeilisearchService = {
    isAvailable: jest.fn(() => true),
    health: jest.fn(async () => undefined),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    mockRedisService.ping.mockResolvedValue(true);
    mockMeilisearchService.isAvailable.mockReturnValue(true);
    mockMeilisearchService.health.mockResolvedValue(undefined);

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
    await app.init();
  });

  afterEach(async () => {
    await app.close();
  });

  it('/api/health (GET)', () => {
    return request(app.getHttpServer())
      .get('/api/health')
      .expect(200)
      .expect((res) => {
        expect(res.body.status).toBe('ok');
        expect(res.body.services.database).toBe('ok');
        expect(res.body.services.redis).toBe('ok');
        expect(res.body.services.meilisearch).toBe('ok');
      });
  });

  it('/api/health reports degraded when Redis is down', async () => {
    mockRedisService.ping.mockResolvedValue(false);

    await request(app.getHttpServer())
      .get('/api/health')
      .expect(200)
      .expect((res) => {
        expect(res.body.status).toBe('degraded');
        expect(res.body.services.redis).toBe('error');
      });
  });
});
