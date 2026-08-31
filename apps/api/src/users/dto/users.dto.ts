import {
  IsBoolean,
  IsEmail,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';
import { Transform } from 'class-transformer';

function emptyToUndefined(value: unknown) {
  if (value === '' || value === null) return undefined;
  return value;
}

export class UpdateUserDto {
  @IsOptional()
  @Transform(({ value }) => emptyToUndefined(value))
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name?: string;

  @IsOptional()
  @Transform(({ value }) => emptyToUndefined(value))
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsBoolean()
  notificationsEnabled?: boolean;
}

export class RegisterFcmTokenDto {
  @IsString()
  @MinLength(10)
  token!: string;

  @IsOptional()
  @IsString()
  platform?: string;
}

export class AddressIdParamDto {
  @IsUUID()
  id!: string;
}

export class CreateAddressDto {
  @IsOptional()
  @IsString()
  @MaxLength(50)
  label?: string;

  @IsString()
  @MinLength(1)
  @MaxLength(100)
  city!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(200)
  street!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(20)
  building!: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  apartment?: string;

  @IsOptional()
  @IsBoolean()
  isDefault?: boolean;
}

export class UpdateAddressDto {
  @IsOptional()
  @IsString()
  @MaxLength(50)
  label?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  city?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  street?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  building?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  apartment?: string;

  @IsOptional()
  @IsBoolean()
  isDefault?: boolean;
}
