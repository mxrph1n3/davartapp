import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../src/app.module';
import { JwtAuthGuard } from '../src/auth/guards/jwt-auth.guard';
import { MeilisearchService } from '../src/meilisearch/meilisearch.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { RedisService } from '../src/redis/redis.service';

const userId = '550e8400-e29b-41d4-a716-446655440099';
const projectId = '550e8400-e29b-41d4-a716-446655440100';
const briefId = '550e8400-e29b-41d4-a716-446655440101';

@Injectable()
class TestAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    request.user = { sub: userId, phone: '+79001234567' };
    return true;
  }
}

describe('Projects (e2e)', () => {
  let app: INestApplication<App>;

  const designer = {
    id: '550e8400-e29b-41d4-a716-446655440200',
    name: 'Анна Дизайнер',
    phone: '+79009999999',
  };

  const brief = {
    id: briefId,
    style: 'Сканди',
    budget: 2500000,
    wishes: 'Светлое пространство',
    rooms: [{ name: 'Гостиная', type: 'living', area: 25 }],
    isLocked: false,
    lockedAt: null,
    updatedAt: new Date(),
  };

  const project = {
    id: projectId,
    userId,
    designerId: designer.id,
    managerId: null,
    surveyorId: null,
    name: 'Квартира ЖК Skyline',
    address: 'Москва, ул. Примерная, 10',
    area: 85,
    style: 'Сканди',
    objectType: 'Квартира',
    startDate: null,
    status: 'brief_filling',
    isShowcase: false,
    designer,
    manager: null,
    surveyor: null,
    brief,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const lockedProject = {
    ...project,
    status: 'in_progress',
    brief: { ...brief, isLocked: true, lockedAt: new Date() },
  };

  const mockPrismaService: any = {
    $connect: jest.fn(),
    $disconnect: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
    $transaction: jest.fn((ops: any) => {
      if (Array.isArray(ops)) {
        return Promise.all(ops);
      }
      return ops(mockPrismaService);
    }),
    project: {
      findMany: jest.fn().mockResolvedValue([project]),
      findFirst: jest.fn().mockResolvedValue(project),
      findUnique: jest.fn().mockResolvedValue(project),
      count: jest.fn().mockResolvedValue(0),
      create: jest.fn(),
      update: jest.fn(),
    },
    brief: {
      upsert: jest.fn().mockResolvedValue(brief),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
    user: {
      upsert: jest.fn().mockResolvedValue(designer),
    },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    mockPrismaService.project.findFirst.mockResolvedValue(project);
    mockPrismaService.project.findUnique.mockResolvedValue(project);
    mockPrismaService.project.create.mockResolvedValue({
      ...project,
      designer: null,
      name: 'Новый проект',
      address: null,
      area: null,
      style: null,
      brief: {
        ...brief,
        style: null,
        budget: null,
        wishes: null,
        rooms: [],
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

  it('GET /api/projects', async () => {
    const response = await request(app.getHttpServer())
      .get('/api/projects')
      .expect(200);

    expect(response.body).toHaveLength(1);
    expect(response.body[0].name).toBe('Квартира ЖК Skyline');
    expect(response.body[0].statusLabel).toBe('Бриф');
  });

  it('POST /api/projects', async () => {
    const response = await request(app.getHttpServer())
      .post('/api/projects')
      .send({ name: 'Новый проект' })
      .expect(201);

    expect(response.body.name).toBe('Новый проект');
    expect(response.body.status).toBe('brief_filling');
    expect(mockPrismaService.project.create).toHaveBeenCalled();
  });

  it('GET /api/projects/:id', async () => {
    const response = await request(app.getHttpServer())
      .get(`/api/projects/${projectId}`)
      .expect(200);

    expect(response.body.id).toBe(projectId);
    expect(response.body.designer?.name).toBe('Анна Дизайнер');
  });

  it('PUT /api/projects/:id/brief', async () => {
    const response = await request(app.getHttpServer())
      .put(`/api/projects/${projectId}/brief`)
      .send({
        style: 'Минимализм',
        budget: 3000000,
        wishes: 'Много света',
        rooms: [{ name: 'Спальня', area: 18 }],
      })
      .expect(200);

    expect(mockPrismaService.brief.upsert).toHaveBeenCalled();
    expect(response.body.isLocked).toBe(false);
  });

  it('PUT /api/projects/:id/brief stores questionnaire answers', async () => {
    mockPrismaService.brief.upsert.mockResolvedValue({
      ...brief,
      answers: {
        general: { likedStyles: 'Сканди', budget: '3000000' },
        rooms: { kids: { included: false } },
      },
    });

    const response = await request(app.getHttpServer())
      .put(`/api/projects/${projectId}/brief`)
      .send({
        answers: {
          general: { likedStyles: 'Сканди', budget: '3000000' },
          rooms: { kids: { included: false } },
        },
      })
      .expect(200);

    expect(mockPrismaService.brief.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        update: expect.objectContaining({
          answers: expect.objectContaining({
            general: expect.objectContaining({ likedStyles: 'Сканди' }),
          }),
        }),
      }),
    );
    expect(response.body.answers.general.likedStyles).toBe('Сканди');
  });

  it('PUT /api/projects/:id/brief returns 403 when locked', async () => {
    mockPrismaService.project.findFirst.mockResolvedValue(lockedProject);

    await request(app.getHttpServer())
      .put(`/api/projects/${projectId}/brief`)
      .send({ style: 'Лофт' })
      .expect(403);
  });

  it('GET /api/projects/:id/brief/pdf', async () => {
    const response = await request(app.getHttpServer())
      .get(`/api/projects/${projectId}/brief/pdf`)
      .expect(200);

    expect(response.headers['content-type']).toContain('application/pdf');
    expect(response.body.length).toBeGreaterThan(0);
  });

  it('POST /api/projects/:id/start-work requires admin secret', async () => {
    await request(app.getHttpServer())
      .post(`/api/projects/${projectId}/start-work`)
      .expect(403);

    const response = await request(app.getHttpServer())
      .post(`/api/projects/${projectId}/start-work`)
      .set('x-admin-secret', 'test-admin-secret')
      .expect(200);

    expect(response.body.message).toContain('locked');
    expect(mockPrismaService.$transaction).toHaveBeenCalled();
  });
});
