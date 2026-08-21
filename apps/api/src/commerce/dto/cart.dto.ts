import { Type } from 'class-transformer';
import {
  IsInt,
  IsOptional,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

export class CartProjectQueryDto {
  @IsUUID()
  projectId!: string;
}

export class AddCartItemDto {
  @IsOptional()
  @IsUUID()
  projectId?: string;

  @IsUUID()
  productId!: string;

  @IsInt()
  @Min(1)
  @Max(99)
  quantity!: number;
}

export class UpdateCartItemDto {
  @IsInt()
  @Min(1)
  @Max(99)
  quantity!: number;
}

export class CartItemIdParamDto {
  @IsUUID()
  id!: string;
}
