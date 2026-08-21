import { Module } from '@nestjs/common';
import { BriefPdfService } from './brief-pdf.service';
import { ProjectsController } from './projects.controller';
import { PublicProjectsController } from './public-projects.controller';
import { ProjectsService } from './projects.service';

@Module({
  controllers: [PublicProjectsController, ProjectsController],
  providers: [ProjectsService, BriefPdfService],
  exports: [ProjectsService],
})
export class ProjectsModule {}
