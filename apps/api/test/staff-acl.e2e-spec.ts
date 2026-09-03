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
import { PushService } from '../src/push/push.service';
import { RedisService } from '../src/redis/redis.service';

const staffId = '550e8400-e29b-41d4-a716-446655440901';
const clientId = '550e8400-e29b-41d4-a716-446655440902';
const otherStaffId = '550e8400-e29b-41d4-a716-446655440903';
const productId = '550e8400-e29b-41d4-a716-446655440001';
const cartId = '550e8400-e29b-41d4-a716-446655440050';
const projectId = '550e8400-e29b-41d4-a716-446655440100';
const briefId = '550e8400-e29b-41d4-a716-446655440101';
const orderId = '550e8400-e29b-41d4-a716-446655440060';

const authState: {
  user: { sub: string; phone: string; role: UserRole };
} = {
  user: {
    sub: staffId,
    phone: '+79009999998',
    role: UserRole.complectator,
  },
};

@Injectable()
class MutableAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest();
    req.user = { ...authState.user };
    return true;
  }
}

describe('Staff ACL (e2e)', () => {
  let app: INestApplication<App>;
  const sendToUser = jest.fn().mockResolvedValue(undefined);

  const clientUser = {
    id: clientId,
    phone: '+79001234567',
    name: 'Клиент Тест',
    email: null,
    role: UserRole.client,
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
  };

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

  const cartItemId = '550e8400-e29b-41d4-a716-446655440051';

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
    userId: clientId,
    designerId: null,
    managerId: null,
    surveyorId: null,
    name: 'Квартира',
    address: 'Москва',
    area: 80,
    style: 'Сканди',
    objectType: 'Квартира',
    startDate: null,
    status: 'brief_filling',
    isShowcase: false,
    designer: null,
    manager: null,
    surveyor: null,
    brief: {
      id: briefId,
      style: 'Сканди',
      budget: 1000000,
      wishes: 'Светло',
      rooms: [],
      isLocked: false,
      lockedAt: null,
      updatedAt: new Date(),
    },
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const createdOrder = {
    id: orderId,
    userId: clientId,
    projectId,
    status: 'created',
    address: 'Москва, ул. Примерная, 1',
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
    statusHistory: [{ id: 'sh-1', status: 'created', createdAt: new Date() }],
  };

  const mockPrismaService: any = {
    $connect: jest.fn(),
    $disconnect: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
    $transaction: jest.fn(async (callback: any) => {
      if (typeof callback === 'function') {
        return callback(mockPrismaService);
      }
      return Promise.all(callback);
    }),
    user: {
      findMany: jest.fn(),
      count: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    project: {
      count: jest.fn().mockResolvedValue(1),
      findMany: jest.fn().mockResolvedValue([project]),
      findFirst: jest.fn().mockResolvedValue(project),
      findUnique: jest.fn().mockResolvedValue({
        id: projectId,
        userId: clientId,
      }),
    },
    order: {
      count: jest.fn().mockResolvedValue(0),
      create: jest.fn().mockResolvedValue(createdOrder),
      findMany: jest.fn().mockResolvedValue([]),
      findFirst: jest.fn(),
    },
    address: {
      count: jest.fn().mockResolvedValue(0),
      findMany: jest.fn().mockResolvedValue([]),
      create: jest.fn(),
    },
    cart: {
      findUnique: jest.fn(),
      upsert: jest.fn().mockResolvedValue({ id: cartId, projectId }),
    },
    cartItem: {
      count: jest.fn().mockResolvedValue(0),
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
    product: {
      findUnique: jest.fn().mockResolvedValue(product),
    },
    brief: {
      findUnique: jest.fn(),
    },
    staffAuditLog: {
      create: jest.fn().mockResolvedValue({ id: 'audit-1' }),
      findMany: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
    },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    authState.user = {
      sub: staffId,
      phone: '+79009999998',
      role: UserRole.complectator,
    };

    mockPrismaService.user.findUnique.mockImplementation(
      async ({ where }: { where: { id: string } }) => {
        if (where.id === clientId) {
          return {
            id: clientId,
            phone: '+79001234567',
            name: 'Клиент Тест',
            email: null,
            birthDate: null,
            role: UserRole.client,
            createdAt: new Date(),
          };
        }
        if (where.id === otherStaffId) {
          return {
            id: otherStaffId,
            phone: '+79009999997',
            name: 'Другой',
            email: null,
            role: UserRole.designer,
            createdAt: new Date(),
          };
        }
        return null;
      },
    );

    mockPrismaService.user.findMany.mockResolvedValue([
      {
        ...clientUser,
        _count: { clientProjects: 1, orders: 0 },
      },
    ]);
    mockPrismaService.user.count.mockResolvedValue(1);

    mockPrismaService.cart.findUnique.mockResolvedValue({
      id: cartId,
      projectId,
      project: { id: projectId, name: project.name, userId: clientId },
      items: cartItems,
    });
    mockPrismaService.cart.upsert.mockResolvedValue({ id: cartId, projectId });
    mockPrismaService.project.findUnique.mockResolvedValue({
      id: projectId,
      userId: clientId,
    });

    mockPrismaService.staffAuditLog.create.mockResolvedValue({ id: 'audit-1' });
    mockPrismaService.staffAuditLog.findMany.mockResolvedValue([
      {
        id: 'audit-1',
        action: 'cart.add',
        meta: { productId, quantity: 1 },
        createdAt: new Date('2026-08-14T00:00:00.000Z'),
        actor: {
          id: staffId,
          name: 'Менеджер',
          phone: '+79009999998',
        },
        client: {
          id: clientId,
          name: 'Клиент Тест',
          phone: '+79001234567',
        },
      },
    ]);
    mockPrismaService.staffAuditLog.count.mockResolvedValue(1);

    mockPrismaService.order.create.mockResolvedValue(createdOrder);
    mockPrismaService.product.findUnique.mockResolvedValue(product);
    mockPrismaService.project.findFirst.mockResolvedValue(project);

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
        ping: jest.fn().mockResolvedValue(true),
      })
      .overrideProvider(MeilisearchService)
      .useValue({
        indexProducts: jest.fn(),
        isAvailable: jest.fn().mockReturnValue(false),
        searchProductIds: jest.fn(),
      })
      .overrideProvider(PushService)
      .useValue({ sendToUser })
      .overrideGuard(JwtAuthGuard)
      .useClass(MutableAuthGuard)
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

  describe('client role forbidden', () => {
    beforeEach(() => {
      authState.user = {
        sub: clientId,
        phone: '+79001234567',
        role: UserRole.client,
      };
    });

    it('GET /api/staff/clients → 403', async () => {
      await request(app.getHttpServer()).get('/api/staff/clients').expect(403);
    });

    it('GET /api/staff/projects/:id/cart → 403', async () => {
      await request(app.getHttpServer())
        .get(`/api/staff/projects/${projectId}/cart`)
        .expect(403);
    });

    it('POST /api/staff/projects/:id/cart/items → 403', async () => {
      await request(app.getHttpServer())
        .post(`/api/staff/projects/${projectId}/cart/items`)
        .send({ productId, quantity: 1 })
        .expect(403);
    });

    it('POST /api/staff/projects/:id/orders → 403', async () => {
      await request(app.getHttpServer())
        .post(`/api/staff/projects/${projectId}/orders`)
        .send({ address: 'Москва' })
        .expect(403);
    });

    it('GET /api/staff/audit → 403', async () => {
      await request(app.getHttpServer()).get('/api/staff/audit').expect(403);
    });
  });

  describe('studio roles allowed', () => {
    it('designer can list clients', async () => {
      authState.user = {
        sub: staffId,
        phone: '+79009999999',
        role: UserRole.designer,
      };

      await request(app.getHttpServer()).get('/api/staff/clients').expect(200);
    });

    it('admin can list clients', async () => {
      authState.user = {
        sub: staffId,
        phone: '+79009999990',
        role: UserRole.admin,
      };

      await request(app.getHttpServer()).get('/api/staff/clients').expect(200);
    });

    it('GET /api/staff/clients lists clients only', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/staff/clients')
        .expect(200);

      expect(response.body.total).toBe(1);
      expect(response.body.items[0].id).toBe(clientId);
      expect(mockPrismaService.user.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            AND: expect.arrayContaining([
              expect.objectContaining({ role: UserRole.client }),
            ]),
          }),
        }),
      );
    });

    it('PATCH /api/staff/clients/:id updates birthDate', async () => {
      const birthDate = new Date('1990-05-12T00:00:00.000Z');
      mockPrismaService.user.update.mockResolvedValue({
        id: clientId,
        phone: '+79001234567',
        name: 'Клиент Тест',
        email: null,
        birthDate,
        createdAt: new Date(),
      });
      mockPrismaService.user.findUnique.mockImplementation(
        async ({ where }: { where: { id: string } }) => {
          if (where.id === clientId) {
            return {
              id: clientId,
              phone: '+79001234567',
              name: 'Клиент Тест',
              email: null,
              birthDate,
              role: UserRole.client,
              createdAt: new Date(),
            };
          }
          return null;
        },
      );

      const response = await request(app.getHttpServer())
        .patch(`/api/staff/clients/${clientId}`)
        .send({ birthDate: '1990-05-12' })
        .expect(200);

      expect(mockPrismaService.user.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            birthDate: expect.any(Date),
          }),
        }),
      );
      expect(response.body.birthDate).toBeTruthy();
    });

    it('GET /api/staff/clients?scope=orders filters clients with orders', async () => {
      await request(app.getHttpServer())
        .get('/api/staff/clients')
        .query({ scope: 'orders' })
        .expect(200);

      expect(mockPrismaService.user.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            AND: expect.arrayContaining([
              expect.objectContaining({ orders: { some: {} } }),
            ]),
          }),
        }),
      );
    });

    it('GET /api/staff/clients/:id/projects/:projectId/brief forces isLocked', async () => {
      const response = await request(app.getHttpServer())
        .get(`/api/staff/clients/${clientId}/projects/${projectId}/brief`)
        .expect(200);

      expect(response.body.isLocked).toBe(true);
      expect(project.brief.isLocked).toBe(false);
    });

    it('rejects non-client id as client target', async () => {
      await request(app.getHttpServer())
        .get(`/api/staff/clients/${otherStaffId}`)
        .expect(404);
    });

    it('POST cart item writes audit and pushes client', async () => {
      const response = await request(app.getHttpServer())
        .post(`/api/staff/projects/${projectId}/cart/items`)
        .send({ productId, quantity: 1 })
        .expect(201);

      expect(response.body.items).toHaveLength(1);
      expect(mockPrismaService.staffAuditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          actorId: staffId,
          clientId,
          action: 'cart.add',
        }),
      });
      expect(sendToUser).toHaveBeenCalledWith(
        clientId,
        expect.objectContaining({
          title: 'Корзина обновлена',
          data: expect.objectContaining({ type: 'cart', projectId }),
        }),
      );
    });

    it('POST order writes audit and pushes client', async () => {
      const response = await request(app.getHttpServer())
        .post(`/api/staff/projects/${projectId}/orders`)
        .send({
          cartItemIds: [cartItemId],
          address: 'Москва, ул. Примерная, 1',
        })
        .expect(201);

      expect(response.body.id).toBe(orderId);
      expect(mockPrismaService.staffAuditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          actorId: staffId,
          clientId,
          action: 'order.create',
        }),
      });
      expect(sendToUser).toHaveBeenCalledWith(
        clientId,
        expect.objectContaining({
          title: 'Заказ оформлен',
          data: expect.objectContaining({ type: 'order', orderId, projectId }),
        }),
      );
    });

    it('GET /api/staff/audit returns staff activity', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/staff/audit')
        .query({ clientId })
        .expect(200);

      expect(response.body.total).toBe(1);
      expect(response.body.items[0].action).toBe('cart.add');
      expect(response.body.items[0].actionLabel).toBe('Добавление в корзину');
      expect(response.body.items[0].actor.id).toBe(staffId);
      expect(response.body.items[0].client.id).toBe(clientId);
    });
  });
});
