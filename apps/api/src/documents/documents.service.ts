import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DocumentType } from '@prisma/client';
import { randomUUID } from 'crypto';
import {
  canAccessAnyClientProject,
  staffAssignedToProjectWhere,
  userCanAccessProjectWhere,
} from '../projects/project-access';
import { isStudioRole } from '../auth/roles';
import { PushService } from '../push/push.service';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import {
  CreateUploadUrlDto,
  DOCUMENT_TYPE_LABELS,
  DOWNLOAD_URL_TTL_SECONDS,
} from './dto/documents.dto';

@Injectable()
export class DocumentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    private readonly pushService: PushService,
  ) {}

  async listForProject(userId: string, projectId: string) {
    await this.ensureUserProject(userId, projectId);

    const documents = await this.prisma.document.findMany({
      where: { projectId },
      orderBy: { uploadedAt: 'desc' },
    });

    return documents.map((document) => this.formatDocument(document));
  }

  async createUploadUrl(
    userId: string,
    projectId: string,
    dto: CreateUploadUrlDto,
  ) {
    await this.ensureUserProject(userId, projectId);

    if (!this.storage.isAvailable()) {
      throw new BadRequestException('File storage is not available');
    }

    const documentId = randomUUID();
    const safeName = dto.name.replace(/[^a-zA-Z0-9._-]/g, '_');
    const storageKey = `projects/${projectId}/documents/${documentId}/${safeName}`;

    const document = await this.prisma.document.create({
      data: {
        id: documentId,
        projectId,
        type: dto.type,
        name: dto.name,
        storageKey,
        mimeType: dto.contentType,
        size: dto.size,
      },
    });

    const uploadUrl = await this.storage.getUploadUrl(
      storageKey,
      dto.contentType,
    );

    return {
      document: this.formatDocument(document),
      uploadUrl,
      expiresIn: 900,
    };
  }

  async getDownloadUrl(userId: string, documentId: string) {
    const document = await this.prisma.document.findUnique({
      where: { id: documentId },
      include: { project: { select: { id: true, userId: true } } },
    });

    if (!document) {
      throw new NotFoundException('Document not found');
    }

    await this.ensureUserProject(userId, document.projectId);

    if (!this.storage.isAvailable()) {
      throw new BadRequestException('File storage is not available');
    }

    const url = await this.storage.getDownloadUrl(document.storageKey);

    return {
      url,
      expiresIn: DOWNLOAD_URL_TTL_SECONDS,
      expiresAt: new Date(Date.now() + DOWNLOAD_URL_TTL_SECONDS * 1000),
      name: document.name,
      mimeType: document.mimeType,
    };
  }

  async seedDemoDocuments(userId: string, projectId: string) {
    await this.ensureUserProject(userId, projectId);

    if (!this.storage.isAvailable()) {
      throw new BadRequestException('File storage is not available');
    }

    const existing = await this.prisma.document.count({ where: { projectId } });
    if (existing > 0) {
      return { message: 'Demo documents already exist' };
    }

    const pdfBuffer = Buffer.from(
      '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n' +
        '2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj\n' +
        '3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R>>endobj\n' +
        'xref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n' +
        '0000000052 00000 n \n0000000101 00000 n \n' +
        'trailer<</Size 4/Root 1 0 R>>\nstartxref\n178\n%%EOF',
    );

    const samples: Array<{
      type: DocumentType;
      name: string;
      mimeType: string;
      body: Buffer;
    }> = [
      {
        type: DocumentType.contract,
        name: 'Договор на дизайн.pdf',
        mimeType: 'application/pdf',
        body: pdfBuffer,
      },
      {
        type: DocumentType.specification,
        name: 'Спецификация материалов.pdf',
        mimeType: 'application/pdf',
        body: pdfBuffer,
      },
      {
        type: DocumentType.invoice,
        name: 'Счёт №001.pdf',
        mimeType: 'application/pdf',
        body: pdfBuffer,
      },
    ];

    const created = [];

    for (const sample of samples) {
      const documentId = randomUUID();
      const storageKey = `projects/${projectId}/documents/${documentId}/${sample.name}`;

      await this.storage.uploadObject(storageKey, sample.body, sample.mimeType);

      const document = await this.prisma.document.create({
        data: {
          id: documentId,
          projectId,
          type: sample.type,
          name: sample.name,
          storageKey,
          mimeType: sample.mimeType,
          size: sample.body.length,
        },
      });

      created.push(this.formatDocument(document));
    }

    const project = await this.prisma.project.findUnique({
      where: { id: projectId },
      select: { userId: true, name: true },
    });

    if (project) {
      await this.pushService.sendToUser(project.userId, {
        title: 'Новый документ',
        body: `В проекте «${project.name}» появились новые документы`,
        data: { type: 'document', projectId },
      });
    }

    return { message: 'Demo documents created', documents: created };
  }

  private async ensureUserProject(userId: string, projectId: string) {
    const viewer = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { role: true, extraRoles: true },
    });
    const roles = viewer ? [viewer.role, ...(viewer.extraRoles ?? [])] : [];

    const asOwner = await this.prisma.project.findFirst({
      where: userCanAccessProjectWhere(userId, projectId),
      select: { id: true },
    });
    if (asOwner) return;

    if (canAccessAnyClientProject(roles)) {
      const project = await this.prisma.project.findFirst({
        where: { id: projectId, isShowcase: false },
        select: { id: true },
      });
      if (project) return;
    }

    if (roles.some((role) => isStudioRole(role))) {
      const assigned = await this.prisma.project.findFirst({
        where: {
          id: projectId,
          ...staffAssignedToProjectWhere(userId),
        },
        select: { id: true },
      });
      if (assigned) return;
    }

    throw new NotFoundException('Project not found');
  }

  private formatDocument(document: {
    id: string;
    projectId: string;
    type: DocumentType;
    name: string;
    mimeType: string | null;
    size: number | null;
    uploadedAt: Date;
  }) {
    return {
      id: document.id,
      projectId: document.projectId,
      type: document.type,
      typeLabel: DOCUMENT_TYPE_LABELS[document.type],
      name: document.name,
      mimeType: document.mimeType,
      size: document.size,
      uploadedAt: document.uploadedAt,
    };
  }
}
