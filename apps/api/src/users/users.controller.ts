import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { JwtPayload } from '../auth/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import {
  AddressIdParamDto,
  CreateAddressDto,
  RegisterFcmTokenDto,
  UpdateAddressDto,
  UpdateUserDto,
} from './dto/users.dto';
import { UsersService } from './users.service';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  getMe(@CurrentUser() user: JwtPayload) {
    return this.usersService.getById(user.sub);
  }

  @Patch('me')
  updateMe(@CurrentUser() user: JwtPayload, @Body() dto: UpdateUserDto) {
    return this.usersService.updateProfile(user.sub, dto);
  }

  @Post('me/fcm-token')
  registerFcmToken(
    @CurrentUser() user: JwtPayload,
    @Body() dto: RegisterFcmTokenDto,
  ) {
    return this.usersService.registerFcmToken(user.sub, dto);
  }

  @Get('me/addresses')
  listAddresses(@CurrentUser() user: JwtPayload) {
    return this.usersService.listAddresses(user.sub);
  }

  @Post('me/addresses')
  createAddress(
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateAddressDto,
  ) {
    return this.usersService.createAddress(user.sub, dto);
  }

  @Patch('me/addresses/:id')
  updateAddress(
    @CurrentUser() user: JwtPayload,
    @Param() params: AddressIdParamDto,
    @Body() dto: UpdateAddressDto,
  ) {
    return this.usersService.updateAddress(user.sub, params.id, dto);
  }

  @Delete('me/addresses/:id')
  deleteAddress(
    @CurrentUser() user: JwtPayload,
    @Param() params: AddressIdParamDto,
  ) {
    return this.usersService.deleteAddress(user.sub, params.id);
  }
}
