import { Module } from '@nestjs/common';
import { LiveSyncModule } from '../live/live-sync.module';
import {
  DocumentsController,
  ProjectDocumentsController,
} from './documents.controller';
import { DocumentsService } from './documents.service';

@Module({
  imports: [LiveSyncModule],
  controllers: [DocumentsController, ProjectDocumentsController],
  providers: [DocumentsService],
  exports: [DocumentsService],
})
export class DocumentsModule {}
