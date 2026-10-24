import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

export enum ProductSort {
  POPULAR = 'popular',
  PRICE_ASC = 'price_asc',
  PRICE_DESC = 'price_desc',
  NEW = 'new',
  DISCOUNT = 'discount',
  STOCK = 'stock',
}

export class SearchQueryDto {
  @IsOptional()
  @IsString()
  q?: string;

  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @IsOptional()
  @IsUUID()
  brandId?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  minPrice?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  maxPrice?: number;

  @IsOptional()
  @IsString()
  material?: string;

  @IsOptional()
  @IsString()
  color?: string;

  @IsOptional()
  @IsString()
  collection?: string;

  /** Characteristic filters, repeated: attr=Размер:60×120&attr=Поверхность:Матовая.
   *  Values of the same key are OR-ed, different keys AND-ed. */
  @IsOptional()
  @Transform(({ value }) =>
    value == null ? undefined : Array.isArray(value) ? value : [value],
  )
  @IsString({ each: true })
  attr?: string[];

  /** Several brands at once (comma-separated ids). */
  @IsOptional()
  @IsString()
  brandIds?: string;

  @IsOptional()
  @Transform(({ value }: { value: unknown }) => {
    if (value === 'true') return true;
    if (value === 'false') return false;
    return value;
  })
  @IsBoolean()
  inStock?: boolean;

  @IsOptional()
  @IsEnum(ProductSort)
  sort?: ProductSort = ProductSort.POPULAR;

  @IsOptional()
  @Type(() => Number)
  @Min(1)
  page?: number = 1;

  @IsOptional()
  @Type(() => Number)
  @Min(1)
  @Max(50)
  limit?: number = 20;
}
