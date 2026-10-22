import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { JwtPayload } from '../auth/decorators/current-user.decorator';
import { assertAdminAccess } from '../common/admin-access';
import {
  CreateOrderDto,
  OrderIdParamDto,
  UpdateOrderStatusDto,
} from './dto/orders.dto';
import { OrdersService } from './orders.service';

@Controller('orders')
@UseGuards(JwtAuthGuard)
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @Post()
  create(@CurrentUser() user: JwtPayload, @Body() dto: CreateOrderDto) {
    return this.ordersService.createFromCart(
      user.sub,
      user.role,
      dto.projectId,
      dto.address,
      dto.comment,
      dto.cartItemIds,
      user.extraRoles ?? [],
    );
  }

  @Get()
  list(@CurrentUser() user: JwtPayload) {
    return this.ordersService.list(user.sub);
  }

  @Get(':id')
  getById(@CurrentUser() user: JwtPayload, @Param() params: OrderIdParamDto) {
    return this.ordersService.getById(user.sub, params.id);
  }

  @Patch(':id/status')
  @HttpCode(200)
  updateStatus(
    @Param() params: OrderIdParamDto,
    @Body() dto: UpdateOrderStatusDto,
    @Headers('x-admin-secret') adminSecret?: string,
  ) {
    assertAdminAccess(adminSecret);
    return this.ordersService.updateStatus(params.id, dto.status);
  }
}
