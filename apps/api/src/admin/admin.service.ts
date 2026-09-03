import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import {
  ASSIGNABLE_ROLES,
  extraRolesOf,
  hasStudioRole,
  isStudioRole,
  primaryRoleOf,
  uniqueRoles,
} from '../auth/roles';
import { ChatService } from '../chat/chat.service';
import { PrismaService } from '../prisma/prisma.service';

const userSelect = {
  id: true,
  phone: true,
  name: true,
  email: true,
  role: true,
  extraRoles: true,
  createdAt: true,
  updatedAt: true,
} as const;

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly chatService: ChatService,
  ) {}

  async createUser(input: { phone: string; role: UserRole; name?: string }) {
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
    input: {
      phone?: string;
      name?: string;
      role?: UserRole;
      roles?: UserRole[];
    },
  ) {
    if (
      !input.phone &&
      input.name === undefined &&
      !input.role &&
      !input.roles
    ) {
      throw new BadRequestException('Nothing to update');
    }

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    const nextRoles = input.roles
      ? uniqueRoles(input.roles)
      : input.role
        ? [input.role]
        : null;

    if (nextRoles) {
      if (nextRoles.length === 0) {
        throw new BadRequestException('At least one role is required');
      }
      if (nextRoles.some((role) => !ASSIGNABLE_ROLES.includes(role))) {
        throw new BadRequestException('Invalid role');
      }
      const nextPrimary = primaryRoleOf(nextRoles);
      if (actorId === userId && nextPrimary !== UserRole.admin) {
        throw new BadRequestException('Cannot demote yourself');
      }
      if (user.role === UserRole.admin && nextPrimary !== UserRole.admin) {
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

    const previousRoles = uniqueRoles([user.role, ...user.extraRoles]);
    const nextPrimary = nextRoles ? primaryRoleOf(nextRoles) : user.role;
    const nextExtra = nextRoles ? extraRolesOf(nextRoles) : user.extraRoles;

    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: {
        ...(input.phone ? { phone: input.phone } : {}),
        ...(input.name !== undefined
          ? { name: input.name.trim() || null }
          : {}),
        ...(nextRoles ? { role: nextPrimary, extraRoles: nextExtra } : {}),
      },
      select: userSelect,
    });

    if (nextRoles) {
      const wasStudio = hasStudioRole(previousRoles);
      const nowStudio = hasStudioRole(nextRoles);
      if (nowStudio && !wasStudio) {
        await this.chatService.syncStaffIntoAllSupportChats(userId);
      }
      if (!nowStudio && wasStudio) {
        await this.chatService.removeStaffFromAllSupportChats(userId);
        await this.chatService.ensureDavartChat(userId);
      }
    }

    return updated;
  }

  async elevateRole(actorId: string, userId: string, role: UserRole) {
    return this.updateUser(actorId, userId, { role });
  }

  async setRoles(actorId: string, userId: string, roles: UserRole[]) {
    return this.updateUser(actorId, userId, { roles });
  }

  async listUsers(params: { page: number; limit: number; q?: string }) {
    const where = params.q?.trim()
      ? {
          OR: [
            {
              name: { contains: params.q.trim(), mode: 'insensitive' as const },
            },
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
          extraRoles: true,
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
