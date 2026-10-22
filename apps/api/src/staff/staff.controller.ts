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
import {
  IsDateString,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
} from 'class-validator';
import type { Response } from 'express';
import { OrderStatus, ProjectStatus, UserRole } from '@prisma/client';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { JwtPayload } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { STUDIO_ROLES } from '../auth/roles';
import { ChatGateway } from '../chat/chat.gateway';
import { ChatService } from '../chat/chat.service';
import { PushService } from '../push/push.service';
import { AddCartItemDto, UpdateCartItemDto } from '../commerce/dto/cart.dto';
import { CreateOrderDto } from '../commerce/dto/orders.dto';
import { CreateProjectDto } from '../projects/dto/projects.dto';
import { CreateAddressDto, UpdateAddressDto } from '../users/dto/users.dto';
import { StaffService } from './staff.service';

class UpdateOrderStatusDto {
  @IsIn(['created', 'confirmed', 'assembling', 'shipping', 'delivered'])
  status!: OrderStatus;
}

class AdvanceProjectStatusDto {
  @IsIn([
    'brief_filling',
    'measurement',
    'in_progress',
    'materials',
    'visualization',
    'final_assembly',
    'completed',
    'archived',
  ])
  status!: ProjectStatus;
}

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

class StaffRosterQueryDto {
  @IsIn(['designer', 'surveyor'])
  role!: 'designer' | 'surveyor';
}

class AssignProjectStaffDto {
  @IsOptional()
  @IsUUID()
  designerId?: string | null;

  @IsOptional()
  @IsUUID()
  surveyorId?: string | null;
}

@Controller('staff')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(...STUDIO_ROLES)
export class StaffController {
  constructor(
    private readonly staffService: StaffService,
    private readonly chatGateway: ChatGateway,
    private readonly chatService: ChatService,
    private readonly pushService: PushService,
  ) {}

  @Get('roster')
  @Roles(UserRole.admin, UserRole.complectator)
  listRoster(@Query() query: StaffRosterQueryDto) {
    return this.staffService.listRoster(query.role);
  }

  @Get('clients')
  @Roles(UserRole.admin, UserRole.complectator)
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

  @Get('clients/:clientId/chat')
  getClientChat(
    @CurrentUser() user: JwtPayload,
    @Param('clientId', ParseUUIDPipe) clientId: string,
  ) {
    return this.staffService.getClientSupportChat(user, clientId);
  }

  @Post('clients/invite')
  inviteClient(
    @CurrentUser() user: JwtPayload,
    @Body() body: { phone?: string; name?: string },
  ) {
    return this.staffService.inviteByPhone(user, body.phone ?? '', body.name);
  }

  @Get('clients/:clientId')
  getClient(
    @CurrentUser() user: JwtPayload,
    @Param('clientId', ParseUUIDPipe) clientId: string,
  ) {
    return this.staffService.getClient(user, clientId);
  }

  @Patch('clients/:clientId')
  updateClient(
    @CurrentUser() user: JwtPayload,
    @Param('clientId', ParseUUIDPipe) clientId: string,
    @Body() dto: UpdateStaffClientDto,
  ) {
    return this.staffService.updateClient(user, clientId, dto);
  }

  @Get('clients/:clientId/addresses')
  listAddresses(
    @CurrentUser() user: JwtPayload,
    @Param('clientId', ParseUUIDPipe) clientId: string,
  ) {
    return this.staffService.listAddresses(user, clientId);
  }

  @Post('clients/:clientId/addresses')
  createAddress(
    @CurrentUser() user: JwtPayload,
    @Param('clientId', ParseUUIDPipe) clientId: string,
    @Body() dto: CreateAddressDto,
  ) {
    return this.staffService.createAddress(user, clientId, dto);
  }

  @Patch('clients/:clientId/addresses/:addressId')
  updateAddress(
    @CurrentUser() user: JwtPayload,
    @Param('clientId', ParseUUIDPipe) clientId: string,
    @Param('addressId', ParseUUIDPipe) addressId: string,
    @Body() dto: UpdateAddressDto,
  ) {
    return this.staffService.updateAddress(user, clientId, addressId, dto);
  }

  @Get('clients/:clientId/projects')
  listProjects(
    @CurrentUser() user: JwtPayload,
    @Param('clientId', ParseUUIDPipe) clientId: string,
  ) {
    return this.staffService.listProjects(user, clientId);
  }

  @Post('clients/:clientId/projects')
  createProject(
    @CurrentUser() user: JwtPayload,
    @Param('clientId', ParseUUIDPipe) clientId: string,
    @Body() dto: CreateProjectDto,
  ) {
    return this.staffService.createProject(user, clientId, dto);
  }

  @Get('clients/:clientId/projects/:projectId')
  getProject(
    @CurrentUser() user: JwtPayload,
    @Param('clientId', ParseUUIDPipe) clientId: string,
    @Param('projectId', ParseUUIDPipe) projectId: string,
  ) {
    return this.staffService.getProject(user, clientId, projectId);
  }

  @Get('clients/:clientId/projects/:projectId/brief')
  getBrief(
    @CurrentUser() user: JwtPayload,
    @Param('clientId', ParseUUIDPipe) clientId: string,
    @Param('projectId', ParseUUIDPipe) projectId: string,
  ) {
    return this.staffService.getBrief(user, clientId, projectId);
  }

  @Get('clients/:clientId/projects/:projectId/brief/pdf')
  async getBriefPdf(
    @CurrentUser() user: JwtPayload,
    @Param('clientId', ParseUUIDPipe) clientId: string,
    @Param('projectId', ParseUUIDPipe) projectId: string,
    @Res() res: Response,
  ) {
    const pdf = await this.staffService.getBriefPdf(user, clientId, projectId);
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
    return this.staffService.getCart(user, projectId);
  }

  @Patch('projects/:projectId/staff')
  @Roles(UserRole.admin, UserRole.complectator)
  async assignProjectStaff(
    @CurrentUser() user: JwtPayload,
    @Param('projectId', ParseUUIDPipe) projectId: string,
    @Body() dto: AssignProjectStaffDto,
  ) {
    const result = await this.staffService.assignProjectStaff(
      user,
      projectId,
      dto,
    );

    for (const notice of result.notices) {
      this.chatGateway.emitNewMessage(notice.chatId, notice.message);
      const otherUserIds = await this.chatService.getOtherParticipantIds(
        notice.chatId,
        user.sub,
      );
      for (const userId of otherUserIds) {
        const total = (await this.chatService.getUnreadTotal(userId)).total;
        this.chatGateway.emitUnreadUpdate(userId, total);
        const push = this.chatService.buildPushPayload(notice.message);
        await this.pushService.sendToUser(userId, {
          title: push.title,
          body: push.body,
          data: { type: 'chat', chatId: notice.chatId },
        });
      }
    }

    return result.project;
  }

  @Post('projects/:projectId/cart/items')
  addCartItem(
    @CurrentUser() user: JwtPayload,
    @Param('projectId', ParseUUIDPipe) projectId: string,
    @Body() dto: AddCartItemDto,
  ) {
    return this.staffService.addCartItem(
      user,
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
      user,
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
    return this.staffService.removeCartItem(user, projectId, itemId);
  }

  @Delete('projects/:projectId/cart')
  @HttpCode(200)
  clearCart(
    @CurrentUser() user: JwtPayload,
    @Param('projectId', ParseUUIDPipe) projectId: string,
  ) {
    return this.staffService.clearCart(user, projectId);
  }

  @Get('clients/:clientId/orders')
  listOrders(
    @CurrentUser() user: JwtPayload,
    @Param('clientId', ParseUUIDPipe) clientId: string,
  ) {
    return this.staffService.listOrders(user, clientId);
  }

  @Get('clients/:clientId/orders/:orderId')
  getOrder(
    @CurrentUser() user: JwtPayload,
    @Param('clientId', ParseUUIDPipe) clientId: string,
    @Param('orderId', ParseUUIDPipe) orderId: string,
  ) {
    return this.staffService.getOrder(user, clientId, orderId);
  }

  @Patch('clients/:clientId/orders/:orderId/status')
  updateOrderStatus(
    @CurrentUser() user: JwtPayload,
    @Param('clientId', ParseUUIDPipe) clientId: string,
    @Param('orderId', ParseUUIDPipe) orderId: string,
    @Body() dto: UpdateOrderStatusDto,
  ) {
    return this.staffService.updateOrderStatus(
      user,
      clientId,
      orderId,
      dto.status,
    );
  }

  @Post('projects/:projectId/status')
  @HttpCode(200)
  advanceProjectStatus(
    @CurrentUser() user: JwtPayload,
    @Param('projectId', ParseUUIDPipe) projectId: string,
    @Body() dto: AdvanceProjectStatusDto,
  ) {
    return this.staffService.advanceProjectStatus(user, projectId, dto.status);
  }

  @Post('projects/:projectId/orders')
  createOrder(
    @CurrentUser() user: JwtPayload,
    @Param('projectId', ParseUUIDPipe) projectId: string,
    @Body() dto: CreateOrderDto,
  ) {
    return this.staffService.createOrder(
      user,
      projectId,
      dto.address,
      dto.comment,
      dto.cartItemIds,
    );
  }

  @Get('audit')
  @Roles(UserRole.admin)
  listAudit(@CurrentUser() user: JwtPayload, @Query() query: ClientsQueryDto) {
    return this.staffService.listAudit(user, {
      page: query.page ?? 1,
      limit: query.limit ?? 30,
      clientId: query.clientId,
    });
  }
}
