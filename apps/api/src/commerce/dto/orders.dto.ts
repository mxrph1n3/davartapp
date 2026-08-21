import {
  ArrayMinSize,
  IsArray,
  IsEnum,
  IsOptional,
  IsString,
  IsUUID,
  MinLength,
} from 'class-validator';
import { OrderStatus } from '@prisma/client';

export class CreateOrderDto {
  @IsOptional()
  @IsUUID()
  projectId?: string;

  /** Selected cart line IDs — at least one unlocked item. */
  @IsArray()
  @ArrayMinSize(1)
  @IsUUID('4', { each: true })
  cartItemIds!: string[];

  @IsString()
  @MinLength(5)
  address!: string;

  @IsOptional()
  @IsString()
  comment?: string;
}

export class OrderIdParamDto {
  @IsUUID()
  id!: string;
}

export class UpdateOrderStatusDto {
  @IsEnum(OrderStatus)
  status!: OrderStatus;
}
