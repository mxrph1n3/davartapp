import {
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { PortfolioKind } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  IsArray,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
} from 'class-validator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { JwtPayload } from '../auth/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt.guard';
import { PortfolioService } from './portfolio.service';

const toArray = ({ value }: { value: unknown }) =>
  value == null ? undefined : Array.isArray(value) ? value : [value];

class PortfolioQueryDto {
  @IsOptional()
  @IsString()
  style?: string;

  @IsOptional()
  @IsEnum(PortfolioKind)
  kind?: PortfolioKind;

  @IsOptional()
  @Transform(toArray)
  @IsArray()
  @IsString({ each: true })
  objectType?: string[];

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  areaMin?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  areaMax?: number;

  @IsOptional()
  @Transform(toArray)
  @IsArray()
  @IsString({ each: true })
  room?: string[];
}

/** Portfolio is open to everyone, without an account («быть максимально открытыми»). */
@Controller('portfolio')
export class PortfolioController {
  constructor(private readonly portfolio: PortfolioService) {}

  @Get('tiles')
  @UseGuards(OptionalJwtAuthGuard)
  tiles(@CurrentUser() user?: JwtPayload) {
    return this.portfolio.tiles(user);
  }

  @Get('filters')
  @UseGuards(OptionalJwtAuthGuard)
  filters(@CurrentUser() user?: JwtPayload) {
    return this.portfolio.filters(user);
  }

  @Get('brief-images')
  briefImages() {
    return this.portfolio.briefImages();
  }

  @Get('favorites')
  @UseGuards(JwtAuthGuard)
  favorites(@CurrentUser() user: JwtPayload) {
    return this.portfolio.favorites(user.sub);
  }

  @Get()
  @UseGuards(OptionalJwtAuthGuard)
  list(@Query() query: PortfolioQueryDto, @CurrentUser() user?: JwtPayload) {
    return this.portfolio.list(query, user);
  }

  @Get(':id')
  @UseGuards(OptionalJwtAuthGuard)
  get(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user?: JwtPayload,
  ) {
    return this.portfolio.get(id, user);
  }

  @Put(':id/favorite')
  @UseGuards(JwtAuthGuard)
  addFavorite(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.portfolio.setFavorite(user.sub, id, true);
  }

  @Delete(':id/favorite')
  @UseGuards(JwtAuthGuard)
  removeFavorite(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.portfolio.setFavorite(user.sub, id, false);
  }
}
