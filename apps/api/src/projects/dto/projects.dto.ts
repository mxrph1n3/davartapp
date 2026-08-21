import { Type } from 'class-transformer';
import {
  IsArray,
  IsIn,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  MinLength,
  ValidateNested,
} from 'class-validator';

export class CreateProjectDto {
  @IsString()
  @MinLength(1)
  name!: string;

  @IsOptional()
  @IsString()
  address?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  area?: number;

  @IsOptional()
  @IsString()
  style?: string;

  @IsOptional()
  @IsString()
  objectType?: string;
}

export class ProjectIdParamDto {
  @IsUUID()
  id!: string;
}

export class InviteProjectMemberDto {
  @IsString()
  @MinLength(10)
  phone!: string;

  @IsOptional()
  @IsIn(['member', 'viewer'])
  role?: 'member' | 'viewer';
}

export class ProjectMemberUserParamDto {
  @IsUUID()
  id!: string;

  @IsUUID()
  userId!: string;
}

export class BriefRoomDto {
  @IsString()
  @MinLength(1)
  name!: string;

  @IsOptional()
  @IsString()
  type?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  area?: number;
}

export class UpdateBriefDto {
  @IsOptional()
  @IsString()
  style?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  budget?: number;

  @IsOptional()
  @IsString()
  wishes?: string;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BriefRoomDto)
  rooms?: BriefRoomDto[];

  @IsOptional()
  @IsObject()
  answers?: Record<string, unknown>;
}
