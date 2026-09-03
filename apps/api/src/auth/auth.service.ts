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

const OTP_LENGTH = 4;
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
    channel: 'telegram' | 'sms' = 'telegram',
  ): Promise<{ message: string; channel: string; debugCode?: string }> {
    await this.ensureRedisAvailable();
    await this.enforceOtpRateLimit(phone);

    // Always 4 digits, no leading zeros — Telegram Gateway may ignore "0042"-style
    // codes and send its own default 6-digit code instead.
    const code = randomInt(1000, 10000).toString();
    await this.redis.set(`otp:${phone}`, this.hashOtp(code), OTP_TTL_SECONDS);
    await this.smsService.sendOtp(phone, code, channel);

    const provider = this.configService.get<string>('SMS_PROVIDER', 'mock');
    const nodeEnv = this.configService.get<string>('NODE_ENV', 'development');
    const debugCode =
      provider === 'mock' && nodeEnv !== 'production' ? code : undefined;

    return {
      message: 'OTP sent',
      channel,
      ...(debugCode ? { debugCode } : {}),
    };
  }

  async verifyOtp(phone: string, code: string): Promise<AuthTokens> {
    await this.ensureRedisAvailable();

    const lockKey = `otp:verify:lock:${phone}`;
    const attemptsKey = `otp:verify:attempts:${phone}`;
    const otpKey = `otp:${phone}`;

    const locked = await this.redis.get(lockKey);
    if (locked) {
      throw new HttpException(
        'Too many invalid OTP attempts. Try again later.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const stored = await this.redis.get(otpKey);
    const matched = stored != null && stored === this.hashOtp(code);

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

    const user = await this.prisma.user.upsert({
      where: { phone },
      update: {},
      create: { phone, role: 'client' },
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
