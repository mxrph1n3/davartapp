import { Injectable } from '@nestjs/common';
import { MeilisearchService } from '../meilisearch/meilisearch.service';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';

type ServiceStatus = 'ok' | 'error' | 'skipped';

@Injectable()
export class HealthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly meilisearch: MeilisearchService,
  ) {}

  async check() {
    const database = await this.checkDatabase();
    const redis = await this.checkRedis();
    const meilisearch = await this.checkMeilisearch();

    const criticalOk = database === 'ok' && redis === 'ok';
    const degradedOptional = meilisearch === 'error';

    return {
      status: !criticalOk ? 'degraded' : degradedOptional ? 'degraded' : 'ok',
      timestamp: new Date().toISOString(),
      services: {
        database,
        redis,
        meilisearch,
      },
    };
  }

  private async checkDatabase(): Promise<ServiceStatus> {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return 'ok';
    } catch {
      return 'error';
    }
  }

  private async checkRedis(): Promise<ServiceStatus> {
    try {
      return (await this.redis.ping()) ? 'ok' : 'error';
    } catch {
      return 'error';
    }
  }

  private async checkMeilisearch(): Promise<ServiceStatus> {
    if (!this.meilisearch.isAvailable()) {
      return 'skipped';
    }

    try {
      await this.meilisearch.health();
      return 'ok';
    } catch {
      return 'error';
    }
  }
}
