import { Type } from 'class-transformer';
import {
  IsEnum,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { ChatType, MessageType } from '@prisma/client';

export class ChatIdParamDto {
  @IsUUID()
  id!: string;
}

export class ProjectChatParamDto {
  @IsUUID()
  projectId!: string;
}

export class AddChatParticipantDto {
  @IsUUID()
  userId!: string;
}

export class CreatePersonalChatDto {
  @IsUUID()
  userId!: string;
}

export class ChatContactsQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  q?: string;
}

export class AssignProjectStaffDto {
  @IsOptional()
  @IsUUID()
  designerId?: string | null;

  @IsOptional()
  @IsUUID()
  surveyorId?: string | null;
}

export class ChatArchiveQueryDto {
  @IsOptional()
  @IsIn(['media', 'files', 'voice', 'links'])
  kind?: 'media' | 'files' | 'voice' | 'links';
}

export class MessagesQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 30;
}

export class SendMessageDto {
  @IsEnum(MessageType)
  type!: MessageType;

  @IsOptional()
  @IsString()
  @MaxLength(5000)
  content?: string;

  @IsOptional()
  @IsString()
  attachmentKey?: string;

  @IsOptional()
  @IsString()
  attachmentName?: string;

  @IsOptional()
  @IsString()
  attachmentMime?: string;

  @IsOptional()
  @IsUUID()
  productId?: string;
}

export class AttachmentUploadUrlDto {
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  fileName!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(255)
  contentType!: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(52428800)
  size?: number;
}

export const CHAT_TYPE_LABELS: Record<ChatType, string> = {
  project: 'Проект',
  personal: 'Личный',
  support: 'DAVart',
};

export const MESSAGE_TYPE_LABELS: Record<MessageType, string> = {
  text: 'Текст',
  image: 'Изображение',
  file: 'Файл',
  product: 'Товар',
  voice: 'Голосовое',
};
