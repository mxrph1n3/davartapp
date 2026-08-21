import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { JwtPayload } from '../auth/decorators/current-user.decorator';
import { CartService } from './cart.service';
import {
  AddCartItemDto,
  CartItemIdParamDto,
  CartProjectQueryDto,
  UpdateCartItemDto,
} from './dto/cart.dto';

@Controller('cart')
@UseGuards(JwtAuthGuard)
export class CartController {
  constructor(private readonly cartService: CartService) {}

  @Get()
  getCart(
    @CurrentUser() user: JwtPayload,
    @Query() query: CartProjectQueryDto,
  ) {
    return this.cartService.getCart(query.projectId, user.sub, user.role);
  }

  @Post('items')
  addItem(@CurrentUser() user: JwtPayload, @Body() dto: AddCartItemDto) {
    if (!dto.projectId) {
      throw new BadRequestException('projectId is required');
    }
    return this.cartService.addItem(
      dto.projectId,
      user.sub,
      user.role,
      dto.productId,
      dto.quantity,
    );
  }

  @Patch('items/:id')
  updateItem(
    @CurrentUser() user: JwtPayload,
    @Param() params: CartItemIdParamDto,
    @Query() query: CartProjectQueryDto,
    @Body() dto: UpdateCartItemDto,
  ) {
    return this.cartService.updateItem(
      query.projectId,
      user.sub,
      user.role,
      params.id,
      dto.quantity,
    );
  }

  @Delete('items/:id')
  removeItem(
    @CurrentUser() user: JwtPayload,
    @Param() params: CartItemIdParamDto,
    @Query() query: CartProjectQueryDto,
  ) {
    return this.cartService.removeItem(
      query.projectId,
      user.sub,
      user.role,
      params.id,
    );
  }

  @Delete()
  @HttpCode(200)
  clearCart(
    @CurrentUser() user: JwtPayload,
    @Query() query: CartProjectQueryDto,
  ) {
    return this.cartService.clearCart(query.projectId, user.sub, user.role);
  }
}
