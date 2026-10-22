import { Module, forwardRef } from '@nestjs/common';
import { ChatModule } from '../chat/chat.module';
import { LiveSyncModule } from '../live/live-sync.module';
import { BriefPdfService } from './brief-pdf.service';
import { ProjectsController } from './projects.controller';
import { PublicProjectsController } from './public-projects.controller';
import { ProjectsService } from './projects.service';

@Module({
  imports: [forwardRef(() => ChatModule), LiveSyncModule],
  controllers: [PublicProjectsController, ProjectsController],
  providers: [ProjectsService, BriefPdfService],
  exports: [ProjectsService],
})
export class ProjectsModule {}
