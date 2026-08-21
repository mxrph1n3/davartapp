import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../src/app.module';
import { JwtAuthGuard } from '../src/auth/guards/jwt-auth.guard';
import { ChatService } from '../src/chat/chat.service';
import { MeilisearchService } from '../src/meilisearch/meilisearch.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { RedisService } from '../src/redis/redis.service';

const adminId = '550e8400-e29b-41d4-a716-446655440990';
const targetUserId = '550e8400-e29b-41d4-a716-446655440902';

const authState: {
  user: { sub: string; phone: string; role: UserRole };
} = {
  user: {
    sub: adminId,
    phone: '+79009999990',
    role: UserRole.admin,
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

describe('Admin Artur Mode (e2e)', () => {
  let app: INestApplication<App>;
  const syncStaff = jest.fn().mockResolvedValue(undefined);
  const ensureDavart = jest.fn().mockResolvedValue(undefined);

  const mockPrismaService: any = {
    $connect: jest.fn(),
    $disconnect: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
    user: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
      update: jest.fn(),
      create: jest.fn(),
    },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    authState.user = {
      sub: adminId,
      phone: '+79009999990',
      role: UserRole.admin,
    };

    mockPrismaService.user.findUnique.mockResolvedValue({
      id: targetUserId,
      phone: '+79001234567',
      name: 'Клиент',
      role: UserRole.client,
    });
    mockPrismaService.user.update.mockResolvedValue({
      id: targetUserId,
      phone: '+79001234567',
      name: 'Клиент',
      email: null,
      role: UserRole.designer,
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    mockPrismaService.user.findMany.mockResolvedValue([]);
    mockPrismaService.user.count.mockResolvedValue(0);

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
      .overrideProvider(ChatService)
      .useValue({
        syncStaffIntoAllSupportChats: syncStaff,
        ensureDavartChat: ensureDavart,
      })
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

  it('client cannot elevate roles', async () => {
    authState.user = {
      sub: targetUserId,
      phone: '+79001234567',
      role: UserRole.client,
    };

    await request(app.getHttpServer())
      .patch(`/api/admin/users/${targetUserId}/role`)
      .send({ role: UserRole.designer })
      .expect(403);
  });

  it('complectator cannot elevate roles', async () => {
    authState.user = {
      sub: '550e8400-e29b-41d4-a716-446655440901',
      phone: '+79009999998',
      role: UserRole.complectator,
    };

    await request(app.getHttpServer())
      .patch(`/api/admin/users/${targetUserId}/role`)
      .send({ role: UserRole.designer })
      .expect(403);
  });

  it('admin can elevate client → designer and syncs support chats', async () => {
    const response = await request(app.getHttpServer())
      .patch(`/api/admin/users/${targetUserId}/role`)
      .send({ role: UserRole.designer })
      .expect(200);

    expect(response.body.role).toBe(UserRole.designer);
    expect(mockPrismaService.user.update).toHaveBeenCalledWith({
      where: { id: targetUserId },
      data: { role: UserRole.designer },
      select: expect.any(Object),
    });
    expect(syncStaff).toHaveBeenCalledWith(targetUserId);
  });

  it('admin can create account by phone', async () => {
    mockPrismaService.user.findUnique.mockResolvedValueOnce(null);
    mockPrismaService.user.create = jest.fn().mockResolvedValue({
      id: 'new-user',
      phone: '+79001112233',
      name: 'Менеджер',
      email: null,
      role: UserRole.complectator,
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    const response = await request(app.getHttpServer())
      .post('/api/admin/users')
      .send({
        phone: '+79001112233',
        role: UserRole.complectator,
        name: 'Менеджер',
      })
      .expect(201);

    expect(response.body.role).toBe(UserRole.complectator);
    expect(response.body.phone).toBe('+79001112233');
    expect(syncStaff).toHaveBeenCalledWith('new-user');
  });

  it('admin can change phone and role together', async () => {
    mockPrismaService.user.findUnique
      .mockResolvedValueOnce({
        id: targetUserId,
        phone: '+79001234567',
        name: 'Клиент',
        role: UserRole.client,
      })
      .mockResolvedValueOnce(null);
    mockPrismaService.user.update.mockResolvedValue({
      id: targetUserId,
      phone: '+79007654321',
      name: 'Дизайнер',
      email: null,
      role: UserRole.designer,
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    const response = await request(app.getHttpServer())
      .patch(`/api/admin/users/${targetUserId}`)
      .send({
        phone: '+79007654321',
        name: 'Дизайнер',
        role: UserRole.designer,
      })
      .expect(200);

    expect(response.body.phone).toBe('+79007654321');
    expect(response.body.role).toBe(UserRole.designer);
  });

  it('GET /api/admin/users is admin-only', async () => {
    await request(app.getHttpServer()).get('/api/admin/users').expect(200);

    authState.user.role = UserRole.designer;
    await request(app.getHttpServer()).get('/api/admin/users').expect(403);
  });
});
