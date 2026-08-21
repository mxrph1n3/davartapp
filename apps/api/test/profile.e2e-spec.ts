import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../src/app.module';
import { JwtAuthGuard } from '../src/auth/guards/jwt-auth.guard';
import { ChatGateway } from '../src/chat/chat.gateway';
import { MeilisearchService } from '../src/meilisearch/meilisearch.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { RedisService } from '../src/redis/redis.service';
import { StorageService } from '../src/storage/storage.service';

const userId = '550e8400-e29b-41d4-a716-446655440099';
const addressId = '550e8400-e29b-41d4-a716-446655440500';

@Injectable()
class TestAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    request.user = { sub: userId, phone: '+79001234567' };
    return true;
  }
}

describe('Profile (e2e)', () => {
  let app: INestApplication<App>;

  const user = {
    id: userId,
    phone: '+79001234567',
    name: 'Клиент',
    email: 'client@example.com',
    notificationsEnabled: true,
    createdAt: new Date(),
  };

  const address = {
    id: addressId,
    userId,
    label: 'Дом',
    city: 'Москва',
    street: 'Примерная',
    building: '10',
    apartment: '5',
    isDefault: true,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const mockPrismaService = {
    $connect: jest.fn(),
    $disconnect: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
    user: {
      findUnique: jest.fn().mockResolvedValue(user),
      update: jest.fn().mockResolvedValue({
        ...user,
        name: 'Новое имя',
      }),
    },
    address: {
      findMany: jest.fn().mockResolvedValue([address]),
      findFirst: jest.fn().mockResolvedValue(address),
      create: jest.fn().mockResolvedValue(address),
      update: jest.fn().mockResolvedValue(address),
      updateMany: jest.fn(),
      delete: jest.fn(),
    },
    fcmToken: {
      upsert: jest.fn().mockResolvedValue({}),
    },
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(PrismaService)
      .useValue(mockPrismaService)
      .overrideProvider(StorageService)
      .useValue({ isAvailable: jest.fn().mockReturnValue(false) })
      .overrideProvider(ChatGateway)
      .useValue({ emitNewMessage: jest.fn(), emitUnreadUpdate: jest.fn(), server: { to: jest.fn().mockReturnValue({ emit: jest.fn() }) } })
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
      .useValue({
        indexProducts: jest.fn(),
        isAvailable: jest.fn().mockReturnValue(false),
        searchProductIds: jest.fn(),
      })
      .overrideGuard(JwtAuthGuard)
      .useClass(TestAuthGuard)
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

  it('PATCH /api/users/me', async () => {
    const response = await request(app.getHttpServer())
      .patch('/api/users/me')
      .send({ name: 'Новое имя', email: 'new@example.com' })
      .expect(200);

    expect(response.body.name).toBe('Новое имя');
  });

  it('GET /api/users/me/addresses', async () => {
    const response = await request(app.getHttpServer())
      .get('/api/users/me/addresses')
      .expect(200);

    expect(response.body).toHaveLength(1);
    expect(response.body[0].city).toBe('Москва');
  });

  it('POST /api/users/me/fcm-token', async () => {
    await request(app.getHttpServer())
      .post('/api/users/me/fcm-token')
      .send({ token: 'test-fcm-token-1234567890', platform: 'ios' })
      .expect(201);

    expect(mockPrismaService.fcmToken.upsert).toHaveBeenCalled();
  });

  it('GET /api/faq', async () => {
    const response = await request(app.getHttpServer())
      .get('/api/faq')
      .expect(200);

    expect(response.body.length).toBeGreaterThan(0);
  });
});
