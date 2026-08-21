import {
  IsBoolean,
  IsEmail,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';

export class UpdateUserDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name?: string;

  @IsOptional()
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
