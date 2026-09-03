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
const productA = '550e8400-e29b-41d4-a716-446655440001';
const productB = '550e8400-e29b-41d4-a716-446655440002';
const projectId = '550e8400-e29b-41d4-a716-446655440100';
const cartId = '550e8400-e29b-41d4-a716-446655440050';
const itemA = '550e8400-e29b-41d4-a716-446655440051';
const itemB = '550e8400-e29b-41d4-a716-446655440052';

@Injectable()
class TestAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest();
    req.user = {
      sub: userId,
      phone: '+79001234567',
      role: UserRole.client,
    };
    return true;
  }
}

describe('Partial checkout + lock (e2e)', () => {
  let app: INestApplication<App>;

  const mkProduct = (id: string, name: string, price: number) => ({
    id,
    name,
    slug: name.toLowerCase(),
    sku: `SKU-${id.slice(-4)}`,
    price,
    compareAtPrice: null,
    imageUrl: null,
    inStock: true,
    isPopular: false,
  });

  const products = {
    [productA]: mkProduct(productA, 'Диван', 45000),
    [productB]: mkProduct(productB, 'Стол', 12000),
  };

  type Item = {
    id: string;
    quantity: number;
    lockedAt: Date | null;
    lockedByOrderId: string | null;
    product: (typeof products)[string];
  };

  const cartState = {
    id: cartId,
    projectId,
    project: { id: projectId, name: 'Квартира', userId },
    items: [] as Item[],
  };

  const mockPrismaService: any = {
    $connect: jest.fn(),
    $disconnect: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
    $transaction: jest.fn((callback: any) => callback(mockPrismaService)),
    product: {
      findUnique: jest.fn(
        async ({ where }: { where: { id: string } }) =>
          products[where.id as keyof typeof products] ?? null,
      ),
    },
    project: {
      findFirst: jest.fn().mockResolvedValue({
        id: projectId,
        isShowcase: false,
        userId,
      }),
    },
    user: {
      findUnique: jest.fn().mockResolvedValue({
        id: userId,
        name: 'Клиент',
        phone: '+79001234567',
      }),
    },
    cart: {
      upsert: jest.fn().mockResolvedValue({ id: cartId, projectId }),
      findUnique: jest.fn(async () => ({
        ...cartState,
        items: cartState.items.map((item) => ({ ...item })),
      })),
    },
    cartItem: {
      findFirst: jest.fn(
        async ({ where }: { where: { id: string; cartId: string } }) =>
          cartState.items.find(
            (i) => i.id === where.id && cartState.id === where.cartId,
          ) ?? null,
      ),
      update: jest.fn(),
      updateMany: jest.fn(
        async ({
          where,
          data,
        }: {
          where: { id: { in: string[] }; lockedAt: null };
          data: { lockedAt: Date; lockedByOrderId: string };
        }) => {
          for (const item of cartState.items) {
            if (where.id.in.includes(item.id) && item.lockedAt == null) {
              item.lockedAt = data.lockedAt;
              item.lockedByOrderId = data.lockedByOrderId;
            }
          }
          return { count: where.id.in.length };
        },
      ),
      delete: jest.fn(),
      deleteMany: jest.fn(),
    },
    order: {
      create: jest.fn(async ({ data, include }: any) => {
        const created = {
          id: 'order-partial-1',
          userId: data.userId,
          projectId: data.projectId,
          status: data.status,
          address: data.address,
          comment: data.comment ?? null,
          totalAmount: data.totalAmount,
          createdAt: new Date(),
          updatedAt: new Date(),
          items: data.items.create.map((item: any, index: number) => ({
            id: `oi-${index}`,
            ...item,
          })),
          statusHistory: [
            { id: 'sh-1', status: 'created', createdAt: new Date() },
          ],
        };
        void include;
        return created;
      }),
    },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    cartState.items = [
      {
        id: itemA,
        quantity: 1,
        lockedAt: null,
        lockedByOrderId: null,
        product: products[productA],
      },
      {
        id: itemB,
        quantity: 2,
        lockedAt: null,
        lockedByOrderId: null,
        product: products[productB],
      },
    ];

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

  it('orders selected items and locks them; other items stay editable', async () => {
    const orderRes = await request(app.getHttpServer())
      .post('/api/orders')
      .send({
        projectId,
        cartItemIds: [itemA],
        address: 'Москва, ул. Примерная, 1',
      })
      .expect(201);

    expect(orderRes.body.items).toHaveLength(1);
    expect(orderRes.body.items[0].productId).toBe(productA);
    expect(orderRes.body.totalAmount).toBe(45000);
    expect(mockPrismaService.cartItem.updateMany).toHaveBeenCalled();

    const cartRes = await request(app.getHttpServer())
      .get('/api/cart')
      .query({ projectId })
      .expect(200);

    expect(cartRes.body.items).toHaveLength(2);
    const locked = cartRes.body.items.find((i: any) => i.id === itemA);
    const open = cartRes.body.items.find((i: any) => i.id === itemB);
    expect(locked.locked).toBe(true);
    expect(open.locked).toBe(false);
    expect(cartRes.body.itemCount).toBe(2);
    expect(cartRes.body.total).toBe(24000);

    await request(app.getHttpServer())
      .patch(`/api/cart/items/${itemA}`)
      .query({ projectId })
      .send({ quantity: 3 })
      .expect(400);

    await request(app.getHttpServer())
      .patch(`/api/cart/items/${itemB}`)
      .query({ projectId })
      .send({ quantity: 3 })
      .expect(200);
  });
});
