import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Res,
  UseGuards,
} from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsDateString, IsIn, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import type { Response } from 'express';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { JwtPayload } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { STUDIO_ROLES } from '../auth/roles';
import {
  AddCartItemDto,
  UpdateCartItemDto,
} from '../commerce/dto/cart.dto';
import { CreateOrderDto } from '../commerce/dto/orders.dto';
import { CreateProjectDto } from '../projects/dto/projects.dto';
import { CreateAddressDto } from '../users/dto/users.dto';
import { StaffService } from './staff.service';

class ClientsQueryDto {
  @IsOptional()
  @IsString()
  q?: string;

  @IsOptional()
  @IsIn(['all', 'projects', 'orders', 'mine'])
  scope?: 'all' | 'projects' | 'orders' | 'mine';

  @IsOptional()
  @IsString()
  clientId?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 30;
}

class UpdateStaffClientDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsString()
  email?: string;

  @IsOptional()
  @IsDateString()
  birthDate?: string;
}

@Controller('staff')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(...STUDIO_ROLES)
export class StaffController {
  constructor(private readonly staffService: StaffService) {}

  @Get('clients')
  listClients(
    @CurrentUser() user: JwtPayload,
    @Query() query: ClientsQueryDto,
  ) {
    return this.staffService.listClients({
      q: query.q,
      scope: query.scope,
      page: query.page ?? 1,
      limit: query.limit ?? 30,
      viewerId: user.sub,
    });
  }

  @Get('clients/:clientId')
  getClient(@Param('clientId', ParseUUIDPipe) clientId: string) {
    return this.staffService.getClient(clientId);
  }

  @Patch('clients/:clientId')
  updateClient(
    @Param('clientId', ParseUUIDPipe) clientId: string,
    @Body() dto: UpdateStaffClientDto,
  ) {
    return this.staffService.updateClient(clientId, dto);
  }

  @Get('clients/:clientId/addresses')
  listAddresses(@Param('clientId', ParseUUIDPipe) clientId: string) {
    return this.staffService.listAddresses(clientId);
  }

  @Post('clients/:clientId/addresses')
  createAddress(
    @CurrentUser() user: JwtPayload,
    @Param('clientId', ParseUUIDPipe) clientId: string,
    @Body() dto: CreateAddressDto,
  ) {
    return this.staffService.createAddress(user.sub, clientId, dto);
  }

  @Get('clients/:clientId/projects')
  listProjects(@Param('clientId', ParseUUIDPipe) clientId: string) {
    return this.staffService.listProjects(clientId);
  }

  @Post('clients/:clientId/projects')
  createProject(
    @Param('clientId', ParseUUIDPipe) clientId: string,
    @Body() dto: CreateProjectDto,
  ) {
    return this.staffService.createProject(clientId, dto);
  }

  @Get('clients/:clientId/projects/:projectId')
  getProject(
    @Param('clientId', ParseUUIDPipe) clientId: string,
    @Param('projectId', ParseUUIDPipe) projectId: string,
  ) {
    return this.staffService.getProject(clientId, projectId);
  }

  @Get('clients/:clientId/projects/:projectId/brief')
  getBrief(
    @Param('clientId', ParseUUIDPipe) clientId: string,
    @Param('projectId', ParseUUIDPipe) projectId: string,
  ) {
    return this.staffService.getBrief(clientId, projectId);
  }

  @Get('clients/:clientId/projects/:projectId/brief/pdf')
  async getBriefPdf(
    @Param('clientId', ParseUUIDPipe) clientId: string,
    @Param('projectId', ParseUUIDPipe) projectId: string,
    @Res() res: Response,
  ) {
    const pdf = await this.staffService.getBriefPdf(clientId, projectId);
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="brief-${projectId}.pdf"`,
    );
    res.send(pdf);
  }

  @Get('projects/:projectId/cart')
  getCart(
    @CurrentUser() user: JwtPayload,
    @Param('projectId', ParseUUIDPipe) projectId: string,
  ) {
    return this.staffService.getCart(user.sub, user.role, projectId);
  }

  @Post('projects/:projectId/cart/items')
  addCartItem(
    @CurrentUser() user: JwtPayload,
    @Param('projectId', ParseUUIDPipe) projectId: string,
    @Body() dto: AddCartItemDto,
  ) {
    return this.staffService.addCartItem(
      user.sub,
      user.role,
      projectId,
      dto.productId,
      dto.quantity,
    );
  }

  @Patch('projects/:projectId/cart/items/:itemId')
  updateCartItem(
    @CurrentUser() user: JwtPayload,
    @Param('projectId', ParseUUIDPipe) projectId: string,
    @Param('itemId', ParseUUIDPipe) itemId: string,
    @Body() dto: UpdateCartItemDto,
  ) {
    return this.staffService.updateCartItem(
      user.sub,
      user.role,
      projectId,
      itemId,
      dto.quantity,
    );
  }

  @Delete('projects/:projectId/cart/items/:itemId')
  removeCartItem(
    @CurrentUser() user: JwtPayload,
    @Param('projectId', ParseUUIDPipe) projectId: string,
    @Param('itemId', ParseUUIDPipe) itemId: string,
  ) {
    return this.staffService.removeCartItem(
      user.sub,
      user.role,
      projectId,
      itemId,
    );
  }

  @Delete('projects/:projectId/cart')
  @HttpCode(200)
  clearCart(
    @CurrentUser() user: JwtPayload,
    @Param('projectId', ParseUUIDPipe) projectId: string,
  ) {
    return this.staffService.clearCart(user.sub, user.role, projectId);
  }

  @Get('clients/:clientId/orders')
  listOrders(@Param('clientId', ParseUUIDPipe) clientId: string) {
    return this.staffService.listOrders(clientId);
  }

  @Get('clients/:clientId/orders/:orderId')
  getOrder(
    @Param('clientId', ParseUUIDPipe) clientId: string,
    @Param('orderId', ParseUUIDPipe) orderId: string,
  ) {
    return this.staffService.getOrder(clientId, orderId);
  }

  @Post('projects/:projectId/orders')
  createOrder(
    @CurrentUser() user: JwtPayload,
    @Param('projectId', ParseUUIDPipe) projectId: string,
    @Body() dto: CreateOrderDto,
  ) {
    return this.staffService.createOrder(
      user.sub,
      user.role,
      projectId,
      dto.address,
      dto.comment,
      dto.cartItemIds,
    );
  }

  @Get('audit')
  listAudit(@Query() query: ClientsQueryDto) {
    return this.staffService.listAudit({
      page: query.page ?? 1,
      limit: query.limit ?? 30,
      clientId: query.clientId,
    });
  }
}
