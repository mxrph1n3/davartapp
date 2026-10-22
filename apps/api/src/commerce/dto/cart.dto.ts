import { Type } from 'class-transformer';
import { IsArray, IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';

export class CartProjectQueryDto {
  @IsOptional()
  @IsUUID()
  projectId?: string;
}

export class AssignCartDto {
  @IsUUID()
  projectId!: string;

  /** When set, only these personal lines move. Omitted means every unlocked line. */
  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  itemIds?: string[];
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
