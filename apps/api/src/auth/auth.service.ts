import {
  BadRequestException,
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
  forwardRef,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { UserRole } from '@prisma/client';
import { createHash, randomBytes, randomInt } from 'crypto';
import { ChatService } from '../chat/chat.service';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';
import { allRolesOf, hasStudioRole } from './roles';
import { SmsService } from './sms.service';

const OTP_TTL_SECONDS = 300;
const OTP_RATE_LIMIT = 10;
const OTP_RATE_WINDOW_SECONDS = 900;
const OTP_VERIFY_MAX_ATTEMPTS = 5;
const OTP_VERIFY_LOCK_SECONDS = 900;

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  user: {
    id: string;
    phone: string;
    name: string | null;
    role: UserRole;
    extraRoles: UserRole[];
  };
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly jwtService: JwtService,
    private readonly smsService: SmsService,
    private readonly configService: ConfigService,
    @Inject(forwardRef(() => ChatService))
    private readonly chatService: ChatService,
  ) {}

  async sendOtp(
    phone: string,
    channel: 'telegram' | 'sms' = 'sms',
  ): Promise<{ message: string; channel: string; debugCode?: string }> {
    await this.ensureRedisAvailable();
    const normalizedPhone = this.normalizePhone(phone);
    await this.enforceOtpRateLimit(normalizedPhone);

    const testCode = this.testLoginCodeFor(normalizedPhone);
    // Always 4 digits for real SMS. Test login may use a fixed code like 0000.
    const code = testCode ?? randomInt(1000, 10000).toString();
    const otpKey = `otp:${normalizedPhone}`;
    const hash = this.hashOtp(code);

    // Keep previous hashes valid briefly so a late SMS from an earlier resend
    // still works (common when delivery is slow).
    const prev = await this.redis.get(otpKey);
    const hashes = new Set<string>([hash]);
    if (prev) {
      try {
        const parsed = JSON.parse(prev) as { hashes?: string[] } | string;
        if (typeof parsed === 'string') {
          hashes.add(parsed);
        } else if (Array.isArray(parsed.hashes)) {
          for (const h of parsed.hashes.slice(-2)) hashes.add(h);
        }
      } catch {
        hashes.add(prev);
      }
    }
    await this.redis.set(
      otpKey,
      JSON.stringify({ hashes: [...hashes] }),
      OTP_TTL_SECONDS,
    );

    // App Review / demo numbers: no SMS, fixed code returned as debugCode.
    if (!testCode) {
      await this.smsService.sendOtp(normalizedPhone, code, channel);
    }

    const provider = this.configService.get<string>('SMS_PROVIDER', 'mock');
    const nodeEnv = this.configService.get<string>('NODE_ENV', 'development');
    const debugCode =
      testCode ??
      (provider === 'mock' && nodeEnv !== 'production' ? code : undefined);

    return {
      message: testCode ? 'OTP ready (test login)' : 'OTP sent',
      channel: testCode ? 'test' : channel,
      ...(debugCode ? { debugCode } : {}),
    };
  }

  async verifyOtp(phone: string, code: string): Promise<AuthTokens> {
    await this.ensureRedisAvailable();
    const normalizedPhone = this.normalizePhone(phone);
    const trimmedCode = code.trim();

    const lockKey = `otp:verify:lock:${normalizedPhone}`;
    const attemptsKey = `otp:verify:attempts:${normalizedPhone}`;
    const otpKey = `otp:${normalizedPhone}`;

    const locked = await this.redis.get(lockKey);
    if (locked) {
      throw new HttpException(
        'Too many invalid OTP attempts. Try again later.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const testCode = this.testLoginCodeFor(normalizedPhone);
    const stored = await this.redis.get(otpKey);
    const codeHash = this.hashOtp(trimmedCode);
    let matched = testCode != null && trimmedCode === testCode;
    if (!matched && stored != null) {
      try {
        const parsed = JSON.parse(stored) as { hashes?: string[] } | string;
        if (typeof parsed === 'string') {
          matched = parsed === codeHash;
        } else if (Array.isArray(parsed.hashes)) {
          matched = parsed.hashes.includes(codeHash);
        }
      } catch {
        matched = stored === codeHash;
      }
    }

    if (!matched) {
      const attempts = await this.redis.incr(attemptsKey);
      if (attempts === 1) {
        await this.redis.expire(attemptsKey, OTP_VERIFY_LOCK_SECONDS);
      }

      if (attempts >= OTP_VERIFY_MAX_ATTEMPTS) {
        await this.redis.set(lockKey, '1', OTP_VERIFY_LOCK_SECONDS);
        await this.redis.del(otpKey);
        await this.redis.del(attemptsKey);
        throw new HttpException(
          'Too many invalid OTP attempts. Try again later.',
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }

      throw new UnauthorizedException('Invalid or expired OTP');
    }

    // Every sign-up starts as a client; studio roles are granted only in the admin panel.
    const user = await this.prisma.user.upsert({
      where: { phone: normalizedPhone },
      update: {},
      create: { phone: normalizedPhone, role: UserRole.client },
      select: {
        id: true,
        phone: true,
        name: true,
        role: true,
        extraRoles: true,
      },
    });

    // Consume OTP only after user row is ready (so DB errors don't burn the code).
    await this.redis.del(otpKey);
    await this.redis.del(attemptsKey);
    await this.redis.del(lockKey);

    const roles = allRolesOf(user);
    if (user.role === UserRole.client && !hasStudioRole(roles)) {
      await this.chatService.ensureDavartChat(user.id);
    }
    if (hasStudioRole(roles)) {
      await this.chatService.syncStaffIntoAllSupportChats(user.id);
    }

    return this.issueTokens(user);
  }

  async refresh(refreshToken: string): Promise<AuthTokens> {
    const tokenHash = this.hashToken(refreshToken);

    const storedToken = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
      include: {
        user: {
          select: {
            id: true,
            phone: true,
            name: true,
            role: true,
            extraRoles: true,
          },
        },
      },
    });

    if (!storedToken || storedToken.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    try {
      await this.prisma.refreshToken.delete({ where: { id: storedToken.id } });
    } catch {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    return this.issueTokens(storedToken.user);
  }

  async logout(refreshToken: string): Promise<{ message: string }> {
    const tokenHash = this.hashToken(refreshToken);

    await this.prisma.refreshToken.deleteMany({ where: { tokenHash } });

    return { message: 'Logged out' };
  }

  private async ensureRedisAvailable(): Promise<void> {
    const ok = await this.redis.ping();
    if (!ok) {
      throw new ServiceUnavailableException('Auth temporarily unavailable');
    }
  }

  private async issueTokens(user: {
    id: string;
    phone: string;
    name?: string | null;
    role: UserRole;
    extraRoles: UserRole[];
  }): Promise<AuthTokens> {
    const accessToken = await this.jwtService.signAsync({
      sub: user.id,
      phone: user.phone,
      role: user.role,
      extraRoles: user.extraRoles,
    });

    const refreshToken = randomBytes(48).toString('hex');
    const refreshExpiresIn = this.configService.get<string>(
      'JWT_REFRESH_EXPIRES_IN',
      '30d',
    );

    await this.prisma.refreshToken.create({
      data: {
        tokenHash: this.hashToken(refreshToken),
        userId: user.id,
        expiresAt: this.parseDuration(refreshExpiresIn),
      },
    });

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        phone: user.phone,
        name: user.name ?? null,
        role: user.role,
        extraRoles: user.extraRoles,
      },
    };
  }

  private async enforceOtpRateLimit(phone: string): Promise<void> {
    const key = `otp:rate:${phone}`;
    const attempts = await this.redis.incr(key);

    if (attempts === 1) {
      await this.redis.expire(key, OTP_RATE_WINDOW_SECONDS);
    }

    if (attempts > OTP_RATE_LIMIT) {
      throw new HttpException(
        'Слишком много запросов кода. Подождите 15 минут или попробуйте другой номер.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  private normalizePhone(phone: string): string {
    const digits = phone.replace(/\D/g, '');
    if (digits.length === 11 && digits.startsWith('8')) {
      return `+7${digits.slice(1)}`;
    }
    if (digits.length === 11 && digits.startsWith('7')) {
      return `+${digits}`;
    }
    if (digits.length === 10) {
      return `+7${digits}`;
    }
    return phone.startsWith('+') ? `+${digits}` : phone.trim();
  }

  /**
   * Fixed OTP for App Review demo numbers (client accounts only). No SMS is sent.
   * Off unless both AUTH_TEST_PHONES and AUTH_TEST_CODE are set (no default code).
   */
  private testLoginCodeFor(phone: string): string | null {
    const code = this.configService.get<string>('AUTH_TEST_CODE', '').trim();
    if (!/^\d{4}$/.test(code)) return null;
    return this.phonesFromEnv('AUTH_TEST_PHONES').includes(phone) ? code : null;
  }

  private phonesFromEnv(key: string): string[] {
    const phonesRaw = this.configService.get<string>(key, '');
    if (!phonesRaw.trim()) return [];
    return phonesRaw
      .split(/[,;\s]+/)
      .map((p) => p.trim())
      .filter(Boolean)
      .map((p) => this.normalizePhone(p));
  }

  private hashOtp(code: string): string {
    return createHash('sha256').update(`davart-otp:${code}`).digest('hex');
  }

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private parseDuration(duration: string): Date {
    const match = duration.match(/^(\d+)([dhms])$/);

    if (!match) {
      throw new BadRequestException('Invalid JWT_REFRESH_EXPIRES_IN format');
    }

    const value = Number(match[1]);
    const unit = match[2];
    const now = Date.now();

    const multipliers: Record<string, number> = {
      d: 86_400_000,
      h: 3_600_000,
      m: 60_000,
      s: 1_000,
    };

    return new Date(now + value * multipliers[unit]);
  }
}
