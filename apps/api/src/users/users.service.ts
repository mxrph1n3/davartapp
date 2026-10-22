import { randomUUID } from 'crypto';
import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import {
  CreateAddressDto,
  RegisterFcmTokenDto,
  UpdateAddressDto,
  UpdateUserDto,
} from './dto/users.dto';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  /** Profile photo for any user (client or staff); shown in chats and contacts. */
  async setAvatar(
    userId: string,
    file: { mimetype: string; size: number; buffer: Buffer } | undefined,
  ) {
    if (!file) throw new BadRequestException('File is required');
    const type = (file.mimetype || '').toLowerCase();
    const ext = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/heic': 'heic', 'image/webp': 'webp' }[type];
    if (!ext) throw new BadRequestException('Только фото: JPG, PNG, HEIC или WEBP');
    if (file.size > 5 * 1024 * 1024) throw new BadRequestException('Фото больше 5 МБ');
    if (!this.storage.isAvailable()) throw new BadRequestException('Хранилище недоступно');
    const key = `avatars/${userId}/${randomUUID()}.${ext}`;
    await this.storage.uploadObject(key, file.buffer, type);
    await this.prisma.user.update({
      where: { id: userId },
      data: { avatarUrl: this.storage.publicUrl(key) },
    });
    return this.getById(userId);
  }

  async removeAvatar(userId: string) {
    await this.prisma.user.update({ where: { id: userId }, data: { avatarUrl: null } });
    return this.getById(userId);
  }

  async getById(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        phone: true,
        name: true,
        avatarUrl: true,
        email: true,
        role: true,
        extraRoles: true,
        notificationsEnabled: true,
        createdAt: true,
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return user;
  }

  async updateProfile(userId: string, dto: UpdateUserDto) {
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: {
        name: dto.name,
        email: dto.email,
        notificationsEnabled: dto.notificationsEnabled,
      },
      select: {
        id: true,
        phone: true,
        name: true,
        avatarUrl: true,
        email: true,
        role: true,
        extraRoles: true,
        notificationsEnabled: true,
        createdAt: true,
      },
    });

    return user;
  }

  async deleteAccount(userId: string) {
    const existing = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true },
    });

    if (!existing) {
      throw new NotFoundException('User not found');
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.order.deleteMany({ where: { userId } });
      await tx.user.delete({ where: { id: userId } });
    });

    return { deleted: true };
  }

  async registerFcmToken(userId: string, dto: RegisterFcmTokenDto) {
    await this.prisma.fcmToken.upsert({
      where: { token: dto.token },
      update: { userId, platform: dto.platform },
      create: { userId, token: dto.token, platform: dto.platform },
    });

    if (dto.platform === 'ios' || dto.platform === 'ios-sandbox') {
      await this.prisma.fcmToken.deleteMany({
        where: { userId, token: { startsWith: 'davart-' } },
      });
    }

    return { message: 'Token registered' };
  }

  async listAddresses(userId: string) {
    const addresses = await this.prisma.address.findMany({
      where: { userId },
      orderBy: [{ isDefault: 'desc' }, { createdAt: 'desc' }],
    });

    return addresses.map((address) => this.formatAddress(address));
  }

  async createAddress(userId: string, dto: CreateAddressDto) {
    if (dto.isDefault) {
      await this.clearDefaultAddress(userId);
    }

    const address = await this.prisma.address.create({
      data: {
        userId,
        label: dto.label,
        city: dto.city,
        street: dto.street,
        building: dto.building,
        apartment: dto.apartment,
        isDefault: dto.isDefault ?? false,
      },
    });

    return this.formatAddress(address);
  }

  async updateAddress(
    userId: string,
    addressId: string,
    dto: UpdateAddressDto,
  ) {
    await this.ensureAddress(userId, addressId);

    if (dto.isDefault) {
      await this.clearDefaultAddress(userId);
    }

    const address = await this.prisma.address.update({
      where: { id: addressId },
      data: dto,
    });

    return this.formatAddress(address);
  }

  async deleteAddress(userId: string, addressId: string) {
    await this.ensureAddress(userId, addressId);
    await this.prisma.address.delete({ where: { id: addressId } });
    return { message: 'Address deleted' };
  }

  private async ensureAddress(userId: string, addressId: string) {
    const address = await this.prisma.address.findFirst({
      where: { id: addressId, userId },
    });

    if (!address) {
      throw new NotFoundException('Address not found');
    }
  }

  private async clearDefaultAddress(userId: string) {
    await this.prisma.address.updateMany({
      where: { userId, isDefault: true },
      data: { isDefault: false },
    });
  }

  private formatAddress(address: {
    id: string;
    label: string | null;
    city: string;
    street: string;
    building: string;
    apartment: string | null;
    isDefault: boolean;
    createdAt: Date;
    updatedAt: Date;
  }) {
    const parts = [address.city, address.street, address.building];
    if (address.apartment) {
      parts.push(`кв. ${address.apartment}`);
    }

    return {
      id: address.id,
      label: address.label,
      city: address.city,
      street: address.street,
      building: address.building,
      apartment: address.apartment,
      isDefault: address.isDefault,
      formatted: parts.join(', '),
      createdAt: address.createdAt,
      updatedAt: address.updatedAt,
    };
  }
}
