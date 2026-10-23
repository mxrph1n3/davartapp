import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AuthModule } from './auth/auth.module';
import { CatalogModule } from './catalog/catalog.module';
import { ChatModule } from './chat/chat.module';
import { CommerceModule } from './commerce/commerce.module';
import { DocumentsModule } from './documents/documents.module';
import { FaqModule } from './faq/faq.module';
import { HealthModule } from './health/health.module';
import { LegalModule } from './legal/legal.module';
import { MeilisearchModule } from './meilisearch/meilisearch.module';
import { PrismaModule } from './prisma/prisma.module';
import { PortfolioModule } from './portfolio/portfolio.module';
import { ProjectsModule } from './projects/projects.module';
import { PushModule } from './push/push.module';
import { RedisModule } from './redis/redis.module';
import { StaffModule } from './staff/staff.module';
import { AdminModule } from './admin/admin.module';
import { StorageModule } from './storage/storage.module';
import { TelegramModule } from './telegram/telegram.module';
import { UsersModule } from './users/users.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ThrottlerModule.forRoot([
      {
        ttl: 60_000,
        limit: process.env.NODE_ENV === 'test' ? 10_000 : 120,
      },
    ]),
    PrismaModule,
    RedisModule,
    StorageModule,
    PushModule,
    MeilisearchModule,
    AuthModule,
    UsersModule,
    CatalogModule,
    CommerceModule,
    ProjectsModule,
    PortfolioModule,
    DocumentsModule,
    ChatModule,
    StaffModule,
    AdminModule,
    TelegramModule,
    FaqModule,
    LegalModule,
    HealthModule,
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule {}
