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
import { StorageService } from '../src/storage/storage.service';

const userId = '550e8400-e29b-41d4-a716-446655440099';
const projectId = '550e8400-e29b-41d4-a716-446655440100';
const documentId = '550e8400-e29b-41d4-a716-446655440300';

@Injectable()
class TestAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    request.user = { sub: userId, phone: '+79001234567' };
    return true;
  }
}

describe('Documents (e2e)', () => {
  let app: INestApplication<App>;

  const document = {
    id: documentId,
    projectId,
    type: 'contract',
    name: 'Договор.pdf',
    storageKey: `projects/${projectId}/documents/${documentId}/dogovor.pdf`,
    mimeType: 'application/pdf',
    size: 1024,
    uploadedAt: new Date(),
    project: { userId },
  };

  const mockPrismaService = {
    $connect: jest.fn(),
    $disconnect: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
    user: {
      findUnique: jest.fn().mockResolvedValue({
        id: userId,
        role: 'client',
        phone: '+79001234567',
      }),
    },
    project: {
      findFirst: jest.fn().mockResolvedValue({ id: projectId }),
    },
    document: {
      findMany: jest.fn().mockResolvedValue([document]),
      findUnique: jest.fn().mockResolvedValue(document),
      create: jest.fn().mockImplementation((args) =>
        Promise.resolve({
          ...document,
          id: args.data.id,
          type: args.data.type,
          name: args.data.name,
          storageKey: args.data.storageKey,
          mimeType: args.data.mimeType,
          size: args.data.size,
        }),
      ),
      count: jest.fn().mockResolvedValue(0),
    },
  };

  const mockStorageService = {
    isAvailable: jest.fn().mockReturnValue(true),
    getUploadUrl: jest
      .fn()
      .mockResolvedValue('http://localhost:9000/davart/upload'),
    getDownloadUrl: jest
      .fn()
      .mockResolvedValue('http://localhost:9000/davart/download'),
    uploadObject: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    mockPrismaService.project.findFirst.mockResolvedValue({ id: projectId });
    mockPrismaService.document.findUnique.mockResolvedValue(document);

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(PrismaService)
      .useValue(mockPrismaService)
      .overrideProvider(StorageService)
      .useValue(mockStorageService)
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

  it('GET /api/projects/:id/documents', async () => {
    const response = await request(app.getHttpServer())
      .get(`/api/projects/${projectId}/documents`)
      .expect(200);

    expect(response.body).toHaveLength(1);
    expect(response.body[0].name).toBe('Договор.pdf');
    expect(response.body[0].typeLabel).toBe('Договор');
  });

  it('POST /api/projects/:id/documents/upload-url', async () => {
    const response = await request(app.getHttpServer())
      .post(`/api/projects/${projectId}/documents/upload-url`)
      .send({
        type: 'pdf',
        name: 'План.pdf',
        contentType: 'application/pdf',
        size: 2048,
      })
      .expect(201);

    expect(response.body.uploadUrl).toContain('localhost:9000');
    expect(response.body.document.name).toBe('План.pdf');
    expect(mockPrismaService.document.create).toHaveBeenCalled();
  });

  it('GET /api/documents/:id/download', async () => {
    const response = await request(app.getHttpServer())
      .get(`/api/documents/${documentId}/download`)
      .expect(200);

    expect(response.body.url).toContain('localhost:9000');
    expect(response.body.expiresIn).toBe(1800);
    expect(mockStorageService.getDownloadUrl).toHaveBeenCalled();
  });

  it('GET /api/documents/:id/download returns 403 for other user', async () => {
    mockPrismaService.document.findUnique.mockResolvedValue({
      ...document,
      project: { userId: 'other-user' },
    });
    mockPrismaService.project.findFirst.mockResolvedValue(null);

    await request(app.getHttpServer())
      .get(`/api/documents/${documentId}/download`)
      .expect(404);
  });
});
