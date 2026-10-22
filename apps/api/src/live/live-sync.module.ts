import { Module, forwardRef } from '@nestjs/common';
import { ChatModule } from '../chat/chat.module';
import { LiveSyncService } from './live-sync.service';

@Module({
  imports: [forwardRef(() => ChatModule)],
  providers: [LiveSyncService],
  exports: [LiveSyncService],
})
export class LiveSyncModule {}
