import { Module } from '@nestjs/common';
import { OpenAppController } from './open-app.controller';
import { TelegramService } from './telegram.service';

@Module({
  controllers: [OpenAppController],
  providers: [TelegramService],
  exports: [TelegramService],
})
export class TelegramModule {}
