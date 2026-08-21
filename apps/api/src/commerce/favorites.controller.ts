import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { JwtPayload } from '../auth/decorators/current-user.decorator';
import {
  FavoriteProductDto,
  FavoriteProductParamDto,
} from './dto/favorites.dto';
import { FavoritesService } from './favorites.service';

@Controller('favorites')
@UseGuards(JwtAuthGuard)
export class FavoritesController {
  constructor(private readonly favoritesService: FavoritesService) {}

  @Get()
  list(@CurrentUser() user: JwtPayload) {
    return this.favoritesService.list(user.sub);
  }

  @Post()
  @HttpCode(200)
  add(@CurrentUser() user: JwtPayload, @Body() dto: FavoriteProductDto) {
    return this.favoritesService.add(user.sub, dto.productId);
  }

  @Delete(':productId')
  @HttpCode(200)
  remove(
    @CurrentUser() user: JwtPayload,
    @Param() params: FavoriteProductParamDto,
  ) {
    return this.favoritesService.remove(user.sub, params.productId);
  }
}
