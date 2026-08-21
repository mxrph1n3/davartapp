import { Type } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { DocumentType } from '@prisma/client';

export class ProjectIdParamDto {
  @IsUUID()
  id!: string;
}

export class DocumentIdParamDto {
  @IsUUID()
  id!: string;
}

export class CreateUploadUrlDto {
  @IsEnum(DocumentType)
  type!: DocumentType;

  @IsString()
  @MinLength(1)
  @MaxLength(255)
  name!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(255)
  contentType!: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  size?: number;
}

export const DOCUMENT_TYPE_LABELS: Record<DocumentType, string> = {
  contract: 'Договор',
  pdf: 'PDF',
  dwg: 'Чертёж DWG',
  specification: 'Спецификация',
  invoice: 'Счёт',
};

export const DOWNLOAD_URL_TTL_SECONDS = 1800;
