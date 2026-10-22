import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { JwtPayload } from '../auth/decorators/current-user.decorator';
import { assertDevEndpointsAllowed } from '../common/dev-endpoints';
import { DocumentsService } from './documents.service';
import {
  CreateUploadUrlDto,
  DocumentIdParamDto,
  ProjectIdParamDto,
} from './dto/documents.dto';

@Controller('documents')
@UseGuards(JwtAuthGuard)
export class DocumentsController {
  constructor(private readonly documentsService: DocumentsService) {}

  @Post(':id/confirm')
  @HttpCode(200)
  confirmUpload(
    @CurrentUser() user: JwtPayload,
    @Param() params: DocumentIdParamDto,
  ) {
    return this.documentsService.confirmUpload(user.sub, params.id);
  }

  @Get(':id/download')
  getDownloadUrl(
    @CurrentUser() user: JwtPayload,
    @Param() params: DocumentIdParamDto,
  ) {
    return this.documentsService.getDownloadUrl(user.sub, params.id);
  }
}

@Controller('projects/:id/documents')
@UseGuards(JwtAuthGuard)
export class ProjectDocumentsController {
  constructor(private readonly documentsService: DocumentsService) {}

  @Get()
  list(@CurrentUser() user: JwtPayload, @Param() params: ProjectIdParamDto) {
    return this.documentsService.listForProject(user.sub, params.id);
  }

  @Post('upload-url')
  createUploadUrl(
    @CurrentUser() user: JwtPayload,
    @Param() params: ProjectIdParamDto,
    @Body() dto: CreateUploadUrlDto,
  ) {
    return this.documentsService.createUploadUrl(user.sub, params.id, dto);
  }

  @Post('seed-demo')
  @HttpCode(200)
  seedDemo(
    @CurrentUser() user: JwtPayload,
    @Param() params: ProjectIdParamDto,
  ) {
    assertDevEndpointsAllowed();
    return this.documentsService.seedDemoDocuments(user.sub, params.id);
  }
}
