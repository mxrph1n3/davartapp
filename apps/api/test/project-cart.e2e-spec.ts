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
const projectA = '550e8400-e29b-41d4-a716-446655440100';
const projectB = '550e8400-e29b-41d4-a716-446655440101';
const cartA = '550e8400-e29b-41d4-a716-446655440050';
const cartB = '550e8400-e29b-41d4-a716-446655440051';

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

describe('Project cart isolation (e2e)', () => {
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

  const products: Record<string, ReturnType<typeof mkProduct>> = {
    [productA]: mkProduct(productA, 'Диван', 45000),
    [productB]: mkProduct(productB, 'Стол', 12000),
  };

  const carts: Record<
    string,
    {
      id: string;
      projectId: string;
      project: { id: string; name: string; userId: string };
      items: Array<{ id: string; quantity: number; product: (typeof products)[string] }>;
    }
  > = {
    [projectA]: {
      id: cartA,
      projectId: projectA,
      project: { id: projectA, name: 'Проект A', userId },
      items: [],
    },
    [projectB]: {
      id: cartB,
      projectId: projectB,
      project: { id: projectB, name: 'Проект B', userId },
      items: [],
    },
  };

  const mockPrismaService: any = {
    $connect: jest.fn(),
    $disconnect: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
    $transaction: jest.fn((callback: any) => callback(mockPrismaService)),
    product: {
      findUnique: jest.fn(async ({ where }: { where: { id: string } }) =>
        products[where.id] ?? null,
      ),
    },
    project: {
      findFirst: jest.fn(async ({ where }: { where: { id?: string } }) => {
        const id = where.id;
        if (!id || !carts[id]) return null;
        return { id, isShowcase: false, userId };
      }),
    },
    cart: {
      upsert: jest.fn(async ({ where }: { where: { projectId: string } }) => ({
        id: carts[where.projectId].id,
        projectId: where.projectId,
      })),
      findUnique: jest.fn(async ({ where }: { where: { id?: string; projectId?: string } }) => {
        if (where.projectId) return carts[where.projectId];
        const byId = Object.values(carts).find((c) => c.id === where.id);
        return byId ?? null;
      }),
    },
    cartItem: {
      findUnique: jest.fn(async ({ where }: any) => {
        const cartId = where.cartId_productId?.cartId;
        const productId = where.cartId_productId?.productId;
        const cart = Object.values(carts).find((c) => c.id === cartId);
        const item = cart?.items.find((i) => i.product.id === productId);
        return item
          ? {
              id: item.id,
              cartId,
              productId,
              quantity: item.quantity,
              lockedAt: null,
            }
          : null;
      }),
      upsert: jest.fn(
        async ({
          where,
          create,
          update,
        }: {
          where: { cartId_productId: { cartId: string; productId: string } };
          create: { cartId: string; productId: string; quantity: number };
          update: { quantity: { increment: number } };
        }) => {
          const cart = Object.values(carts).find(
            (c) => c.id === where.cartId_productId.cartId,
          )!;
          const existing = cart.items.find(
            (i) => i.product.id === where.cartId_productId.productId,
          );
          if (existing) {
            existing.quantity += update.quantity.increment;
            return existing;
          }
          const item = {
            id: `item-${create.productId}`,
            quantity: create.quantity,
            product: products[create.productId],
          };
          cart.items.push(item);
          return item;
        },
      ),
      deleteMany: jest.fn(),
    },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    carts[projectA].items = [];
    carts[projectB].items = [];

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

  it('keeps cart items isolated between projects', async () => {
    await request(app.getHttpServer())
      .post('/api/cart/items')
      .send({ projectId: projectA, productId: productA, quantity: 1 })
      .expect(201);

    await request(app.getHttpServer())
      .post('/api/cart/items')
      .send({ projectId: projectB, productId: productB, quantity: 2 })
      .expect(201);

    const cartARes = await request(app.getHttpServer())
      .get('/api/cart')
      .query({ projectId: projectA })
      .expect(200);

    const cartBRes = await request(app.getHttpServer())
      .get('/api/cart')
      .query({ projectId: projectB })
      .expect(200);

    expect(cartARes.body.projectId).toBe(projectA);
    expect(cartARes.body.items).toHaveLength(1);
    expect(cartARes.body.items[0].product.id).toBe(productA);
    expect(cartARes.body.itemCount).toBe(1);

    expect(cartBRes.body.projectId).toBe(projectB);
    expect(cartBRes.body.items).toHaveLength(1);
    expect(cartBRes.body.items[0].product.id).toBe(productB);
    expect(cartBRes.body.itemCount).toBe(2);
  });
});
