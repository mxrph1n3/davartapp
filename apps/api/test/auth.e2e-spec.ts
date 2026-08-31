import { createHash } from 'crypto';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { RedisService } from '../src/redis/redis.service';

function hashOtp(code: string): string {
  return createHash('sha256').update(`davart-otp:${code}`).digest('hex');
}

describe('Auth (e2e)', () => {
  let app: INestApplication<App>;
  const redisStore = new Map<string, string>();

  const mockRedisService = {
    ping: jest.fn(async () => true),
    get: jest.fn(async (key: string) => redisStore.get(key) ?? null),
    set: jest.fn(async (key: string, value: string) => {
      redisStore.set(key, value);
    }),
    compareAndDelete: jest.fn(async (key: string, expected: string) => {
      const current = redisStore.get(key);
      if (current !== expected) return false;
      redisStore.delete(key);
      return true;
    }),
    incr: jest.fn(async (key: string) => {
      const current = Number(redisStore.get(key) ?? '0') + 1;
      redisStore.set(key, String(current));
      return current;
    }),
    expire: jest.fn(async () => undefined),
    del: jest.fn(async (...keys: string[]) => {
      keys.forEach((key) => redisStore.delete(key));
    }),
    ttl: jest.fn(async () => -1),
  };

  const mockPrismaService = {
    $connect: jest.fn(),
    $disconnect: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
    user: {
      findMany: jest.fn().mockResolvedValue([]),
      upsert: jest.fn().mockResolvedValue({
        id: 'user-1',
        phone: '+79001234567',
        name: null,
        role: 'client',
        extraRoles: [],
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
      findUnique: jest.fn().mockResolvedValue({
        id: 'user-1',
        phone: '+79001234567',
        name: null,
        role: 'client',
        extraRoles: [],
        createdAt: new Date(),
      }),
    },
    chatParticipant: {
      findFirst: jest.fn().mockResolvedValue(null),
      upsert: jest.fn(),
      createMany: jest.fn(),
      create: jest.fn(),
    },
    chat: {
      findMany: jest.fn().mockResolvedValue([]),
      create: jest.fn().mockResolvedValue({
        id: 'chat-1',
        type: 'support',
        title: 'DAVart',
        projectId: null,
        updatedAt: new Date(),
        participants: [],
        messages: [],
        project: null,
      }),
      update: jest.fn(),
      findUnique: jest.fn(),
    },
    refreshToken: {
      create: jest.fn().mockResolvedValue({ id: 'rt-1' }),
      findUnique: jest.fn(),
      delete: jest.fn(),
      deleteMany: jest.fn(),
    },
  };

  beforeEach(async () => {
    redisStore.clear();
    jest.clearAllMocks();
    mockRedisService.ping.mockResolvedValue(true);

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(PrismaService)
      .useValue(mockPrismaService)
      .overrideProvider(RedisService)
      .useValue(mockRedisService)
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

  it('POST /api/auth/send-otp', async () => {
    const response = await request(app.getHttpServer())
      .post('/api/auth/send-otp')
      .send({ phone: '+79001234567' })
      .expect(200);

    expect(response.body.message).toBe('OTP sent');
    expect(response.body.debugCode).toMatch(/^\d{6}$/);
    expect(redisStore.get('otp:+79001234567')).toBe(
      hashOtp(response.body.debugCode as string),
    );
  });

  it('POST /api/auth/send-otp fails when Redis is down', async () => {
    mockRedisService.ping.mockResolvedValue(false);

    await request(app.getHttpServer())
      .post('/api/auth/send-otp')
      .send({ phone: '+79001234567' })
      .expect(503);
  });

  it('POST /api/auth/verify-otp with invalid code', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/verify-otp')
      .send({ phone: '+79001234567', code: '123456' })
      .expect(401);
  });

  it('POST /api/auth/verify-otp with valid code', async () => {
    redisStore.set('otp:+79001234567', hashOtp('123456'));

    const response = await request(app.getHttpServer())
      .post('/api/auth/verify-otp')
      .send({ phone: '+79001234567', code: '123456' })
      .expect(200);

    expect(response.body.accessToken).toBeDefined();
    expect(response.body.refreshToken).toBeDefined();
    expect(response.body.user).toBeDefined();
    expect(response.body.user.phone).toBe('+79001234567');
  });

  it('POST /api/auth/verify-otp locks after too many attempts', async () => {
    redisStore.set('otp:+79001234567', hashOtp('999999'));

    for (let i = 0; i < 4; i += 1) {
      await request(app.getHttpServer())
        .post('/api/auth/verify-otp')
        .send({ phone: '+79001234567', code: '000000' })
        .expect(401);
    }

    await request(app.getHttpServer())
      .post('/api/auth/verify-otp')
      .send({ phone: '+79001234567', code: '000000' })
      .expect(429);

    await request(app.getHttpServer())
      .post('/api/auth/verify-otp')
      .send({ phone: '+79001234567', code: '999999' })
      .expect(429);
  });

  it('POST /api/auth/refresh and logout', async () => {
    redisStore.set('otp:+79001234567', hashOtp('123456'));

    const verified = await request(app.getHttpServer())
      .post('/api/auth/verify-otp')
      .send({ phone: '+79001234567', code: '123456' })
      .expect(200);

    const refreshToken = verified.body.refreshToken as string;

    mockPrismaService.refreshToken.findUnique.mockImplementation(
      async ({ where }: { where: { tokenHash: string } }) => ({
        id: 'rt-1',
        tokenHash: where.tokenHash,
        expiresAt: new Date(Date.now() + 60_000),
        user: {
          id: 'user-1',
          phone: '+79001234567',
          role: 'client',
          extraRoles: [],
        },
      }),
    );

    const refreshed = await request(app.getHttpServer())
      .post('/api/auth/refresh')
      .send({ refreshToken })
      .expect(200);

    expect(refreshed.body.accessToken).toBeDefined();
    expect(refreshed.body.refreshToken).toBeDefined();

    await request(app.getHttpServer())
      .post('/api/auth/logout')
      .send({ refreshToken: refreshed.body.refreshToken })
      .expect(200)
      .expect({ message: 'Logged out' });

    expect(mockPrismaService.refreshToken.deleteMany).toHaveBeenCalled();
  });

  it('POST /api/auth/refresh with invalid token', async () => {
    mockPrismaService.refreshToken.findUnique.mockResolvedValue(null);

    await request(app.getHttpServer())
      .post('/api/auth/refresh')
      .send({ refreshToken: 'not-a-real-token' })
      .expect(401);
  });
});
