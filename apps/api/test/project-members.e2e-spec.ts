import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { ProjectMemberRole, UserRole } from '@prisma/client';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../src/app.module';
import { JwtAuthGuard } from '../src/auth/guards/jwt-auth.guard';
import { MeilisearchService } from '../src/meilisearch/meilisearch.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { RedisService } from '../src/redis/redis.service';

const ownerId = '550e8400-e29b-41d4-a716-446655440099';
const memberId = '550e8400-e29b-41d4-a716-446655440088';
const projectId = '550e8400-e29b-41d4-a716-446655440100';

const authState: {
  user: { sub: string; phone: string; role: UserRole };
} = {
  user: { sub: ownerId, phone: '+79001234567', role: UserRole.client },
};

@Injectable()
class MutableAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest();
    req.user = { ...authState.user };
    return true;
  }
}

describe('Project members M2M (e2e)', () => {
  let app: INestApplication<App>;

  const project = {
    id: projectId,
    userId: ownerId,
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
    brief: null,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const mockPrismaService: any = {
    $connect: jest.fn(),
    $disconnect: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
    $transaction: jest.fn(async (ops: any) => {
      if (Array.isArray(ops)) return Promise.all(ops);
      return ops(mockPrismaService);
    }),
    project: {
      findMany: jest.fn().mockResolvedValue([project]),
      findFirst: jest.fn().mockResolvedValue(project),
      findUnique: jest.fn().mockResolvedValue({ userId: ownerId }),
      count: jest.fn().mockResolvedValue(0),
      create: jest.fn(),
      update: jest.fn(),
    },
    projectMember: {
      findMany: jest.fn().mockResolvedValue([
        {
          id: 'pm-1',
          role: ProjectMemberRole.owner,
          createdAt: new Date(),
          user: {
            id: ownerId,
            phone: '+79001234567',
            name: 'Владелец',
            role: UserRole.client,
          },
        },
      ]),
      findUnique: jest.fn().mockResolvedValue(null),
      create: jest.fn(),
      delete: jest.fn(),
    },
    user: {
      upsert: jest.fn().mockResolvedValue({
        id: memberId,
        phone: '+79001234568',
        role: UserRole.client,
      }),
    },
    chat: {
      findMany: jest.fn().mockResolvedValue([{ id: 'chat-1' }]),
    },
    chatParticipant: {
      upsert: jest.fn(),
    },
    brief: {
      upsert: jest.fn(),
      updateMany: jest.fn(),
    },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    authState.user = {
      sub: ownerId,
      phone: '+79001234567',
      role: UserRole.client,
    };

    mockPrismaService.project.findFirst.mockResolvedValue(project);
    mockPrismaService.project.findUnique.mockResolvedValue({ userId: ownerId });
    mockPrismaService.projectMember.findUnique.mockResolvedValue({
      role: ProjectMemberRole.owner,
    });
    mockPrismaService.projectMember.create.mockResolvedValue({
      id: 'pm-2',
      role: ProjectMemberRole.member,
      createdAt: new Date(),
      user: {
        id: memberId,
        phone: '+79001234568',
        name: null,
        role: UserRole.client,
      },
    });

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

  it('lists members for project owner', async () => {
    const response = await request(app.getHttpServer())
      .get(`/api/projects/${projectId}/members`)
      .expect(200);

    expect(response.body.items).toHaveLength(1);
    expect(response.body.items[0].role).toBe('owner');
  });

  it('member can access project via membership ACL', async () => {
    authState.user = {
      sub: memberId,
      phone: '+79001234568',
      role: UserRole.client,
    };
    mockPrismaService.project.findFirst.mockResolvedValue({
      ...project,
      userId: ownerId,
    });

    await request(app.getHttpServer())
      .get(`/api/projects/${projectId}`)
      .expect(200);
  });

  it('owner invites member by phone and adds to project chats', async () => {
    mockPrismaService.projectMember.findUnique
      .mockResolvedValueOnce({ role: ProjectMemberRole.owner }) // manage check
      .mockResolvedValueOnce(null); // existing membership

    const response = await request(app.getHttpServer())
      .post(`/api/projects/${projectId}/members`)
      .send({ phone: '+79001234568' })
      .expect(201);

    expect(response.body.user.id).toBe(memberId);
    expect(mockPrismaService.chatParticipant.upsert).toHaveBeenCalled();
  });

  it('non-owner member cannot invite', async () => {
    authState.user = {
      sub: memberId,
      phone: '+79001234568',
      role: UserRole.client,
    };
    mockPrismaService.projectMember.findUnique.mockResolvedValue({
      role: ProjectMemberRole.member,
    });

    await request(app.getHttpServer())
      .post(`/api/projects/${projectId}/members`)
      .send({ phone: '+79001234569' })
      .expect(403);
  });
});
