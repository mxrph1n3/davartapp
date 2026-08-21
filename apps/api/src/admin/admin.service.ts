import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { ASSIGNABLE_ROLES, isStudioRole } from '../auth/roles';
import { ChatService } from '../chat/chat.service';
import { PrismaService } from '../prisma/prisma.service';

const userSelect = {
  id: true,
  phone: true,
  name: true,
  email: true,
  role: true,
  createdAt: true,
  updatedAt: true,
} as const;

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly chatService: ChatService,
  ) {}

  async createUser(input: {
    phone: string;
    role: UserRole;
    name?: string;
  }) {
    if (!ASSIGNABLE_ROLES.includes(input.role)) {
      throw new BadRequestException('Invalid role');
    }

    const existing = await this.prisma.user.findUnique({
      where: { phone: input.phone },
    });
    if (existing) {
      throw new ConflictException('User with this phone already exists');
    }

    const created = await this.prisma.user.create({
      data: {
        phone: input.phone,
        role: input.role,
        name: input.name?.trim() || null,
      },
      select: userSelect,
    });

    if (isStudioRole(input.role)) {
      await this.chatService.syncStaffIntoAllSupportChats(created.id);
    } else {
      await this.chatService.ensureDavartChat(created.id);
    }

    return created;
  }

  async updateUser(
    actorId: string,
    userId: string,
    input: { phone?: string; name?: string; role?: UserRole },
  ) {
    if (!input.phone && input.name === undefined && !input.role) {
      throw new BadRequestException('Nothing to update');
    }

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    if (input.role) {
      if (!ASSIGNABLE_ROLES.includes(input.role)) {
        throw new BadRequestException('Invalid role');
      }
      if (actorId === userId && input.role !== UserRole.admin) {
        throw new BadRequestException('Cannot demote yourself');
      }
      if (
        user.role === UserRole.admin &&
        input.role !== UserRole.admin
      ) {
        await this.ensureNotLastAdmin(userId);
      }
    }

    if (input.phone && input.phone !== user.phone) {
      const taken = await this.prisma.user.findUnique({
        where: { phone: input.phone },
      });
      if (taken) {
        throw new ConflictException('Phone already used by another account');
      }
    }

    const previousRole = user.role;
    const nextRole = input.role ?? previousRole;

    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: {
        ...(input.phone ? { phone: input.phone } : {}),
        ...(input.name !== undefined
          ? { name: input.name.trim() || null }
          : {}),
        ...(input.role ? { role: input.role } : {}),
      },
      select: userSelect,
    });

    if (input.role && nextRole !== previousRole) {
      if (isStudioRole(nextRole) && !isStudioRole(previousRole)) {
        await this.chatService.syncStaffIntoAllSupportChats(userId);
      }
      if (nextRole === UserRole.client && isStudioRole(previousRole)) {
        await this.chatService.removeStaffFromAllSupportChats(userId);
        await this.chatService.ensureDavartChat(userId);
      }
    }

    return updated;
  }

  async elevateRole(actorId: string, userId: string, role: UserRole) {
    return this.updateUser(actorId, userId, { role });
  }

  async listUsers(params: { page: number; limit: number; q?: string }) {
    const where = params.q?.trim()
      ? {
          OR: [
            { name: { contains: params.q.trim(), mode: 'insensitive' as const } },
            { phone: { contains: params.q.trim() } },
          ],
        }
      : {};

    const skip = (params.page - 1) * params.limit;
    const [items, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        select: {
          id: true,
          phone: true,
          name: true,
          email: true,
          role: true,
          createdAt: true,
        },
        orderBy: [{ role: 'asc' }, { phone: 'asc' }],
        skip,
        take: params.limit,
      }),
      this.prisma.user.count({ where }),
    ]);

    return { items, total, page: params.page, limit: params.limit };
  }

  private async ensureNotLastAdmin(userId: string) {
    const adminCount = await this.prisma.user.count({
      where: { role: UserRole.admin },
    });
    if (adminCount <= 1) {
      throw new BadRequestException('Cannot demote the last admin');
    }
    void userId;
  }
}
