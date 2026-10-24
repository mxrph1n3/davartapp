import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { JwtPayload } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { AdminService } from './admin.service';
import {
  AdminUserIdParamDto,
  CreateAdminUserDto,
  ElevateRoleDto,
  SetRolesDto,
  UpdateAdminUserDto,
} from './dto/admin.dto';

class AdminUsersQueryDto {
  @IsOptional()
  @IsString()
  q?: string;

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

/** Режим Бога: only admin (Artur). Create accounts, change phones, assign roles. */
@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.admin)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('users')
  listUsers(@Query() query: AdminUsersQueryDto) {
    return this.adminService.listUsers({
      q: query.q,
      page: query.page ?? 1,
      limit: query.limit ?? 30,
    });
  }

  @Post('users')
  createUser(@Body() dto: CreateAdminUserDto) {
    return this.adminService.createUser({
      phone: dto.phone,
      role: dto.role,
      name: dto.name,
    });
  }

  @Patch('users/:id')
  updateUser(
    @CurrentUser() actor: JwtPayload,
    @Param() params: AdminUserIdParamDto,
    @Body() dto: UpdateAdminUserDto,
  ) {
    return this.adminService.updateUser(actor.sub, params.id, {
      phone: dto.phone,
      name: dto.name,
      role: dto.role,
      roles: dto.roles,
    });
  }

  /** Assign role to any user by id. */
  @Patch('users/:id/role')
  elevateRole(
    @CurrentUser() actor: JwtPayload,
    @Param() params: AdminUserIdParamDto,
    @Body() dto: ElevateRoleDto,
  ) {
    return this.adminService.elevateRole(actor.sub, params.id, dto.role);
  }

  @Patch('users/:id/roles')
  setRoles(
    @CurrentUser() actor: JwtPayload,
    @Param() params: AdminUserIdParamDto,
    @Body() dto: SetRolesDto,
  ) {
    return this.adminService.setRoles(actor.sub, params.id, dto.roles);
  }
}
