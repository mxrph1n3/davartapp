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
const chatId = '550e8400-e29b-41d4-a716-446655440400';
const messageId = '550e8400-e29b-41d4-a716-446655440401';

@Injectable()
class TestAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    request.user = { sub: userId, phone: '+79001234567' };
    return true;
  }
}

describe('Chat (e2e)', () => {
  let app: INestApplication<App>;

  const sender = { id: userId, name: 'Клиент', phone: '+79001234567' };
  const message = {
    id: messageId,
    chatId,
    senderId: userId,
    type: 'text',
    content: 'Привет!',
    attachmentKey: null,
    attachmentName: null,
    attachmentMime: null,
    productId: null,
    createdAt: new Date(),
    sender,
    product: null,
  };

  const participant = {
    id: 'participant-1',
    chatId,
    userId,
    unreadCount: 1,
    lastReadAt: null,
    chat: {
      id: chatId,
      type: 'support',
      title: 'Поддержка Davart',
      projectId: null,
      updatedAt: new Date(),
      project: null,
      messages: [message],
    },
  };

  const mockPrismaService: any = {
    $connect: jest.fn(),
    $disconnect: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
    $transaction: jest.fn((callback: any) => {
      if (typeof callback === 'function') {
        return callback(mockPrismaService);
      }
      return Promise.all(callback);
    }),
    chatParticipant: {
      findMany: jest.fn().mockResolvedValue([participant]),
      findUnique: jest.fn().mockResolvedValue(participant),
      aggregate: jest.fn().mockResolvedValue({ _sum: { unreadCount: 1 } }),
      update: jest.fn(),
      updateMany: jest.fn(),
      count: jest.fn().mockResolvedValue(0),
    },
    message: {
      findMany: jest.fn().mockResolvedValue([message]),
      count: jest.fn().mockResolvedValue(1),
      create: jest.fn().mockResolvedValue(message),
    },
    chat: {
      update: jest.fn(),
      create: jest.fn(),
      findUnique: jest.fn().mockResolvedValue({
        id: chatId,
        type: 'support',
        title: 'Поддержка Davart',
        projectId: null,
        project: null,
        participants: [
          {
            user: {
              id: userId,
              name: 'Клиент',
              phone: '+79001234567',
              role: 'client',
            },
          },
        ],
      }),
    },
    product: {
      findUnique: jest.fn(),
    },
    user: {
      upsert: jest.fn(),
      findUnique: jest.fn().mockResolvedValue({ notificationsEnabled: true }),
    },
    fcmToken: {
      findMany: jest.fn().mockResolvedValue([]),
    },
    project: {
      findFirst: jest.fn().mockResolvedValue(null),
    },
  };

  const mockChatGateway = {
    emitNewMessage: jest.fn(),
    emitUnreadUpdate: jest.fn(),
    server: { to: jest.fn().mockReturnValue({ emit: jest.fn() }) },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    mockPrismaService.chatParticipant.findUnique.mockResolvedValue(participant);
    mockPrismaService.message.create.mockResolvedValue(message);

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(PrismaService)
      .useValue(mockPrismaService)
      .overrideProvider(StorageService)
      .useValue({
        isAvailable: jest.fn().mockReturnValue(true),
        getDownloadUrl: jest
          .fn()
          .mockResolvedValue('http://localhost:9000/file'),
        getUploadUrl: jest.fn().mockResolvedValue('http://localhost:9000/upload'),
      })
      .overrideProvider(ChatGateway)
      .useValue(mockChatGateway)
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

  it('GET /api/chats', async () => {
    const response = await request(app.getHttpServer())
      .get('/api/chats')
      .expect(200);

    expect(response.body).toHaveLength(1);
    expect(response.body[0].title).toBe('DAVart');
    expect(response.body[0].unreadCount).toBe(1);
  });

  it('GET /api/chats/:id/messages', async () => {
    const response = await request(app.getHttpServer())
      .get(`/api/chats/${chatId}/messages`)
      .expect(200);

    expect(response.body.items).toHaveLength(1);
    expect(response.body.items[0].content).toBe('Привет!');
    expect(response.body.items[0].isMine).toBe(true);
  });

  it('POST /api/chats/:id/messages', async () => {
    const response = await request(app.getHttpServer())
      .post(`/api/chats/${chatId}/messages`)
      .send({ type: 'text', content: 'Новое сообщение' })
      .expect(201);

    expect(response.body.content).toBe('Привет!');
    expect(mockChatGateway.emitNewMessage).toHaveBeenCalled();
  });

  it('POST /api/chats/:id/read', async () => {
    await request(app.getHttpServer())
      .post(`/api/chats/${chatId}/read`)
      .expect(200);

    expect(mockPrismaService.chatParticipant.update).toHaveBeenCalled();
  });

  it('GET /api/chats/unread-total', async () => {
    const response = await request(app.getHttpServer())
      .get('/api/chats/unread-total')
      .expect(200);

    expect(response.body.total).toBe(1);
  });

  it('GET /api/chats/:id', async () => {
    const response = await request(app.getHttpServer())
      .get(`/api/chats/${chatId}`)
      .expect(200);

    expect(response.body.id).toBe(chatId);
    expect(response.body.participants).toHaveLength(1);
    expect(response.body.participants[0].phone).toBe('');
  });

  it('GET /api/chats/:id/archive', async () => {
    mockPrismaService.message.findMany.mockResolvedValueOnce([
      {
        ...message,
        type: 'image',
        content: null,
        attachmentKey: 'chats/img.jpg',
        attachmentName: 'photo.jpg',
        sender,
      },
      {
        ...message,
        id: 'link-1',
        type: 'text',
        content: 'Смотри https://davart.ru/catalog',
        sender,
      },
    ]);

    const media = await request(app.getHttpServer())
      .get(`/api/chats/${chatId}/archive`)
      .query({ kind: 'media' })
      .expect(200);

    expect(media.body.items).toHaveLength(1);
    expect(media.body.items[0].type).toBe('image');

    mockPrismaService.message.findMany.mockResolvedValueOnce([
      {
        ...message,
        id: 'link-1',
        type: 'text',
        content: 'Смотри https://davart.ru/catalog',
        sender,
      },
    ]);

    const links = await request(app.getHttpServer())
      .get(`/api/chats/${chatId}/archive`)
      .query({ kind: 'links' })
      .expect(200);

    expect(links.body.items).toHaveLength(1);
    expect(links.body.items[0].urls).toContain('https://davart.ru/catalog');
  });
});
