import {
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
  AssignCartDto,
  CartItemIdParamDto,
  CartProjectQueryDto,
  RemoveCartItemsDto,
  UpdateCartItemDto,
} from './dto/cart.dto';

@Controller('cart')
@UseGuards(JwtAuthGuard)
export class CartController {
  constructor(private readonly cartService: CartService) {}

  @Get('projects')
  listProjectCarts(@CurrentUser() user: JwtPayload) {
    return this.cartService.listProjectCarts(user.sub);
  }

  @Get()
  getCart(
    @CurrentUser() user: JwtPayload,
    @Query() query: CartProjectQueryDto,
  ) {
    return this.cartService.getCart(
      query.projectId,
      user.sub,
      user.role,
      user.extraRoles ?? [],
    );
  }

  @Post('assign')
  @HttpCode(200)
  assign(@CurrentUser() user: JwtPayload, @Body() dto: AssignCartDto) {
    return this.cartService.assignPersonalCart(
      user.sub,
      user.role,
      dto.projectId,
      user.extraRoles ?? [],
      dto.itemIds,
    );
  }

  @Post('items')
  addItem(@CurrentUser() user: JwtPayload, @Body() dto: AddCartItemDto) {
    return this.cartService.addItem(
      dto.projectId,
      user.sub,
      user.role,
      dto.productId,
      dto.quantity,
      user.extraRoles ?? [],
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
      user.extraRoles ?? [],
    );
  }

  @Post('items/remove')
  @HttpCode(200)
  removeItems(
    @CurrentUser() user: JwtPayload,
    @Body() dto: RemoveCartItemsDto,
  ) {
    return this.cartService.removeItems(
      dto.projectId,
      user.sub,
      user.role,
      dto.itemIds,
      user.extraRoles ?? [],
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
      user.extraRoles ?? [],
    );
  }

  @Delete()
  @HttpCode(200)
  clearCart(
    @CurrentUser() user: JwtPayload,
    @Query() query: CartProjectQueryDto,
  ) {
    return this.cartService.clearCart(
      query.projectId,
      user.sub,
      user.role,
      user.extraRoles ?? [],
    );
  }
}
