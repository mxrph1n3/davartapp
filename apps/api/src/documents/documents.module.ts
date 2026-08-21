import { Module } from '@nestjs/common';
import {
  DocumentsController,
  ProjectDocumentsController,
} from './documents.controller';
import { DocumentsService } from './documents.service';

@Module({
  controllers: [DocumentsController, ProjectDocumentsController],
  providers: [DocumentsService],
  exports: [DocumentsService],
})
export class DocumentsModule {}
