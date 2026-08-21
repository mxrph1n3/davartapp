import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../src/app.module';
import { JwtAuthGuard } from '../src/auth/guards/jwt-auth.guard';
import { MeilisearchService } from '../src/meilisearch/meilisearch.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { RedisService } from '../src/redis/redis.service';

const userId = '550e8400-e29b-41d4-a716-446655440099';
const productId = '550e8400-e29b-41d4-a716-446655440001';
const cartId = '550e8400-e29b-41d4-a716-446655440050';
const cartItemId = '550e8400-e29b-41d4-a716-446655440051';
const projectId = '550e8400-e29b-41d4-a716-446655440100';

@Injectable()
class TestAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    request.user = {
      sub: userId,
      phone: '+79001234567',
      role: UserRole.client,
    };
    return true;
  }
}

describe('Commerce (e2e)', () => {
  let app: INestApplication<App>;

  const product = {
    id: productId,
    name: 'Диван',
    slug: 'divan',
    sku: 'DAV-00001',
    price: 45000,
    compareAtPrice: null,
    imageUrl: null,
    inStock: true,
    isPopular: false,
  };

  const cartItems = [
    {
      id: cartItemId,
      quantity: 1,
      lockedAt: null,
      lockedByOrderId: null,
      product,
    },
  ];

  const project = {
    id: projectId,
    name: 'Квартира',
    userId,
    isShowcase: false,
  };

  const mockPrismaService: any = {
    $connect: jest.fn(),
    $disconnect: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
    $transaction: jest.fn((callback: any) => callback(mockPrismaService)),
    product: {
      findUnique: jest.fn().mockResolvedValue(product),
    },
    project: {
      findFirst: jest.fn().mockResolvedValue(project),
      findUnique: jest.fn().mockResolvedValue(project),
    },
    cart: {
      upsert: jest.fn().mockResolvedValue({ id: cartId, projectId }),
      findUnique: jest.fn().mockResolvedValue({
        id: cartId,
        projectId,
        project,
        items: cartItems,
      }),
    },
    cartItem: {
      upsert: jest.fn(),
      findFirst: jest.fn().mockResolvedValue({
        id: cartItemId,
        cartId,
        lockedAt: null,
      }),
      findUnique: jest.fn().mockResolvedValue(null),
      update: jest.fn(),
      updateMany: jest.fn(),
      delete: jest.fn(),
      deleteMany: jest.fn(),
    },
    user: {
      findUnique: jest.fn().mockResolvedValue({
        id: userId,
        name: 'Клиент',
        phone: '+79001234567',
      }),
    },
    favorite: {
      findMany: jest.fn().mockResolvedValue([]),
      findUnique: jest.fn().mockResolvedValue(null),
      create: jest.fn(),
      delete: jest.fn(),
    },
    order: {
      create: jest.fn().mockResolvedValue({
        id: 'order-1',
        userId,
        projectId,
        status: 'created',
        address: 'Москва',
        comment: null,
        totalAmount: 45000,
        createdAt: new Date(),
        updatedAt: new Date(),
        items: [
          {
            id: 'oi-1',
            productId,
            quantity: 1,
            price: 45000,
            name: 'Диван',
            sku: 'DAV-00001',
          },
        ],
        statusHistory: [
          { id: 'sh-1', status: 'created', createdAt: new Date() },
        ],
      }),
      findMany: jest.fn().mockResolvedValue([]),
      findFirst: jest.fn(),
    },
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

  it('GET /api/cart?projectId=', async () => {
    const response = await request(app.getHttpServer())
      .get('/api/cart')
      .query({ projectId })
      .expect(200);

    expect(response.body.items).toHaveLength(1);
    expect(response.body.total).toBe(45000);
    expect(response.body.projectId).toBe(projectId);
  });

  it('POST /api/cart/items', async () => {
    await request(app.getHttpServer())
      .post('/api/cart/items')
      .send({ projectId, productId, quantity: 1 })
      .expect(201);

    expect(mockPrismaService.cartItem.upsert).toHaveBeenCalled();
  });

  it('POST /api/orders', async () => {
    const response = await request(app.getHttpServer())
      .post('/api/orders')
      .send({
        projectId,
        cartItemIds: [cartItemId],
        address: 'Москва, ул. Примерная, 1',
      })
      .expect(201);

    expect(response.body.status).toBe('created');
    expect(response.body.statusLabel).toBe('Оформлен');
  });
});
