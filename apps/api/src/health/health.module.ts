import { Module } from '@nestjs/common';
import { MeilisearchModule } from '../meilisearch/meilisearch.module';
import { HealthController } from './health.controller';
import { HealthService } from './health.service';

@Module({
  imports: [MeilisearchModule],
  controllers: [HealthController],
  providers: [HealthService],
})
export class HealthModule {}
