import { IsUUID } from 'class-validator';

export class FavoriteProductDto {
  @IsUUID()
  productId!: string;
}

export class FavoriteProductParamDto {
  @IsUUID()
  productId!: string;
}
