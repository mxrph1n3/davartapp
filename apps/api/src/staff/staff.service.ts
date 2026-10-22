import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { OrderStatus, Prisma, ProjectStatus, UserRole } from '@prisma/client';
import { canSeeContactPhone } from '../auth/roles';
import { ChatService } from '../chat/chat.service';
import { CartService } from '../commerce/cart.service';
import { OrdersService } from '../commerce/orders.service';
import { LiveSyncService } from '../live/live-sync.service';
import { PrismaService } from '../prisma/prisma.service';
import { ProjectsService } from '../projects/projects.service';
import { clientLinkedToStaffWhere } from '../projects/project-access';
import { PushService } from '../push/push.service';
import { CreateProjectDto } from '../projects/dto/projects.dto';
import { CreateAddressDto, UpdateAddressDto } from '../users/dto/users.dto';
import { UsersService } from '../users/users.service';
import type { JwtPayload } from '../auth/decorators/current-user.decorator';

const STAFF_ACTION_LABELS: Record<string, string> = {
  'cart.add': 'Добавление в корзину',
  'cart.update': 'Изменение корзины',
  'cart.remove': 'Удаление из корзины',
  'cart.clear': 'Очистка корзины',
  'order.create': 'Оформление заказа',
  'address.create': 'Добавление адреса',
};

@Injectable()
export class StaffService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly usersService: UsersService,
    private readonly projectsService: ProjectsService,
    private readonly cartService: CartService,
    private readonly ordersService: OrdersService,
    private readonly pushService: PushService,
    private readonly chatService: ChatService,
    private readonly liveSync: LiveSyncService,
  ) {}

  async listClients(params: {
    q?: string;
    scope?: 'all' | 'projects' | 'orders' | 'mine';
    page: number;
    limit: number;
    viewerId: string;
  }) {
    const and: Prisma.UserWhereInput[] = [{ role: UserRole.client }];

    const q = params.q?.trim();
    if (q) {
      and.push({
        OR: [
          { name: { contains: q, mode: 'insensitive' } },
          { phone: { contains: q } },
          { email: { contains: q, mode: 'insensitive' } },
        ],
      });
    }

    if (params.scope === 'orders') {
      and.push({ orders: { some: {} } });
    }
    if (params.scope === 'projects') {
      and.push({
        OR: [
          { clientProjects: { some: { isShowcase: false } } },
          { projectMemberships: { some: { project: { isShowcase: false } } } },
        ],
      });
    }
    if (params.scope === 'mine') {
      and.push({
        OR: [
          { clientProjects: { some: { designerId: params.viewerId } } },
          {
            projectMemberships: {
              some: { project: { designerId: params.viewerId } },
            },
          },
        ],
      });
    }

    const where: Prisma.UserWhereInput = { AND: and };
    const skip = (params.page - 1) * params.limit;
    const [items, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        select: {
          id: true,
          phone: true,
          name: true,
          email: true,
          birthDate: true,
          createdAt: true,
          _count: {
            select: {
              clientProjects: true,
              orders: true,
            },
          },
        },
        orderBy: [{ name: 'asc' }, { phone: 'asc' }],
        skip,
        take: params.limit,
      }),
      this.prisma.user.count({ where }),
    ]);

    const counts = await this.projectCartCounts(items.map((user) => user.id));

    return {
      items: items.map((user) =>
        this.formatClientSummary(user, counts.get(user.id) ?? 0),
      ),
      total,
      page: params.page,
      limit: params.limit,
    };
  }

  async getClient(actor: JwtPayload, clientId: string) {
    await this.assertClientAccess(actor, clientId);
    const user = await this.requireClient(clientId);
    const [projectsCount, ordersCount, addressesCount, cartItemsCount] =
      await Promise.all([
        this.prisma.project.count({
          where: {
            isShowcase: false,
            OR: [
              { userId: clientId },
              { members: { some: { userId: clientId } } },
            ],
          },
        }),
        this.prisma.order.count({ where: { userId: clientId } }),
        this.prisma.address.count({ where: { userId: clientId } }),
        this.prisma.cartItem.count({
          where: {
            cart: {
              project: {
                isShowcase: false,
                OR: [
                  { userId: clientId },
                  { members: { some: { userId: clientId } } },
                ],
              },
            },
          },
        }),
      ]);

    return {
      id: user.id,
      phone: user.phone,
      name: user.name,
      email: user.email,
      birthDate: user.birthDate,
      createdAt: user.createdAt,
      projectsCount,
      ordersCount,
      addressesCount,
      cartItemsCount,
    };
  }

  async updateClient(
    actor: JwtPayload,
    clientId: string,
    dto: { name?: string; email?: string; birthDate?: string },
  ) {
    await this.assertClientAccess(actor, clientId);

    await this.prisma.user.update({
      where: { id: clientId },
      data: {
        name: dto.name,
        email: dto.email,
        birthDate: dto.birthDate ? new Date(dto.birthDate) : undefined,
      },
    });

    return this.getClient(actor, clientId);
  }

  async listAddresses(actor: JwtPayload, clientId: string) {
    await this.assertClientAccess(actor, clientId);
    return this.usersService.listAddresses(clientId);
  }

  async listProjects(actor: JwtPayload, clientId: string) {
    await this.assertClientAccess(actor, clientId);
    return this.projectsService.listForUser(clientId);
  }

  async createProject(
    actor: JwtPayload,
    clientId: string,
    dto: CreateProjectDto,
  ) {
    await this.assertClientAccess(actor, clientId);
    return this.projectsService.create(clientId, dto);
  }

  async getProject(actor: JwtPayload, clientId: string, projectId: string) {
    await this.assertClientAccess(actor, clientId);
    return this.projectsService.getById(clientId, projectId);
  }

  async getBrief(actor: JwtPayload, clientId: string, projectId: string) {
    await this.assertClientAccess(actor, clientId);
    return this.projectsService.getBrief(clientId, projectId);
  }

  async getBriefPdf(actor: JwtPayload, clientId: string, projectId: string) {
    await this.assertClientAccess(actor, clientId);
    return this.projectsService.generateBriefPdf(clientId, projectId);
  }

  /** What the client collected for themselves — the designer uses it for the подборка. */
  async getClientPersonalCart(actor: JwtPayload, clientId: string) {
    await this.assertClientAccess(actor, clientId);
    return this.cartService.getPersonalCartOf(clientId);
  }

  async getCart(actor: JwtPayload, projectId: string) {
    return this.cartService.getCart(
      projectId,
      actor.sub,
      actor.role,
      actor.extraRoles ?? [],
    );
  }

  async addCartItem(
    actor: JwtPayload,
    projectId: string,
    productId: string,
    quantity: number,
  ) {
    const cart = await this.cartService.addItem(
      projectId,
      actor.sub,
      actor.role,
      productId,
      quantity,
      actor.extraRoles ?? [],
    );

    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      select: { name: true },
    });

    const clientId = cart.ownerUserId;

    await this.recordAudit(actor.sub, clientId, 'cart.add', {
      productId,
      quantity,
      productName: product?.name ?? null,
      projectId,
    });

    return cart;
  }

  async updateCartItem(
    actor: JwtPayload,
    projectId: string,
    itemId: string,
    quantity: number,
  ) {
    const cart = await this.cartService.updateItem(
      projectId,
      actor.sub,
      actor.role,
      itemId,
      quantity,
      actor.extraRoles ?? [],
    );
    await this.recordAudit(actor.sub, cart.ownerUserId, 'cart.update', {
      itemId,
      quantity,
      projectId,
    });
    return cart;
  }

  async removeCartItem(actor: JwtPayload, projectId: string, itemId: string) {
    const cart = await this.cartService.removeItem(
      projectId,
      actor.sub,
      actor.role,
      itemId,
      actor.extraRoles ?? [],
    );
    await this.recordAudit(actor.sub, cart.ownerUserId, 'cart.remove', {
      itemId,
      projectId,
    });
    return cart;
  }

  async clearCart(actor: JwtPayload, projectId: string) {
    const cart = await this.cartService.clearCart(
      projectId,
      actor.sub,
      actor.role,
      actor.extraRoles ?? [],
    );
    await this.recordAudit(actor.sub, cart.ownerUserId, 'cart.clear', {
      projectId,
    });
    return cart;
  }

  async createOrder(
    actor: JwtPayload,
    projectId: string,
    address: string,
    comment?: string,
    cartItemIds?: string[],
  ) {
    const order = await this.ordersService.createFromCart(
      actor.sub,
      actor.role,
      projectId,
      address,
      comment,
      cartItemIds,
      actor.extraRoles ?? [],
    );

    const clientId = order.userId ?? (await this.ownerIdForProject(projectId));

    await this.recordAudit(actor.sub, clientId, 'order.create', {
      orderId: order.id,
      totalAmount: order.totalAmount,
      address,
      projectId,
    });

    await this.pushService.sendToUser(clientId, {
      title: 'Заказ оформлен',
      body: `Команда DAVart оформила заказ на ${order.totalAmount.toLocaleString('ru-RU')} ₽`,
      data: { type: 'order', orderId: order.id, projectId },
    });

    return order;
  }

  private async ownerIdForProject(projectId: string) {
    const project = await this.prisma.project.findUnique({
      where: { id: projectId },
      select: { userId: true },
    });
    if (!project) throw new NotFoundException('Project not found');
    return project.userId;
  }

  async listOrders(actor: JwtPayload, clientId: string) {
    await this.assertClientAccess(actor, clientId);
    return this.ordersService.list(clientId);
  }

  async getOrder(actor: JwtPayload, clientId: string, orderId: string) {
    await this.assertClientAccess(actor, clientId);
    return this.ordersService.getById(clientId, orderId);
  }

  async updateOrderStatus(
    actor: JwtPayload,
    clientId: string,
    orderId: string,
    status: OrderStatus,
  ) {
    const current = await this.getOrder(actor, clientId, orderId);
    const flow: OrderStatus[] = [
      OrderStatus.created,
      OrderStatus.confirmed,
      OrderStatus.assembling,
      OrderStatus.shipping,
      OrderStatus.delivered,
    ];
    const from = flow.indexOf(current.status);
    const to = flow.indexOf(status);
    if (to !== from + 1) {
      throw new BadRequestException('Можно перейти только на следующий статус');
    }
    return this.ordersService.updateStatus(orderId, status);
  }

  async advanceProjectStatus(
    actor: JwtPayload,
    projectId: string,
    status: ProjectStatus,
  ) {
    const project = await this.prisma.project.findFirst({
      where: { id: projectId, isShowcase: false },
      select: { userId: true },
    });
    if (!project) {
      throw new NotFoundException('Project not found');
    }
    await this.assertClientAccess(actor, project.userId);
    return this.projectsService.advanceStatus(projectId, status);
  }

  async createAddress(
    actor: JwtPayload,
    clientId: string,
    dto: CreateAddressDto,
  ) {
    await this.assertClientAccess(actor, clientId);
    const address = await this.usersService.createAddress(clientId, dto);
    await this.recordAudit(actor.sub, clientId, 'address.create', {
      addressId: address.id,
      city: dto.city,
    });
    return address;
  }

  /** Staff and the client can both edit an address — whoever filled it in first. */
  async updateAddress(
    actor: JwtPayload,
    clientId: string,
    addressId: string,
    dto: UpdateAddressDto,
  ) {
    await this.assertClientAccess(actor, clientId);
    const address = await this.usersService.updateAddress(clientId, addressId, dto);
    await this.recordAudit(actor.sub, clientId, 'address.update', { addressId });
    return address;
  }

  async listAudit(
    actor: JwtPayload,
    params: { page: number; limit: number; clientId?: string },
  ) {
    const roles = [actor.role, ...(actor.extraRoles ?? [])];
    if (!roles.includes(UserRole.admin)) {
      throw new ForbiddenException('Audit is admin-only');
    }

    const where: Prisma.StaffAuditLogWhereInput = {};
    if (params.clientId) {
      where.clientId = params.clientId;
    }

    const skip = (params.page - 1) * params.limit;
    const [items, total] = await Promise.all([
      this.prisma.staffAuditLog.findMany({
        where,
        include: {
          actor: { select: { id: true, name: true, phone: true } },
          client: { select: { id: true, name: true, phone: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: params.limit,
      }),
      this.prisma.staffAuditLog.count({ where }),
    ]);

    return {
      items: items.map((row) => ({
        id: row.id,
        action: row.action,
        actionLabel: STAFF_ACTION_LABELS[row.action] ?? row.action,
        meta: row.meta,
        createdAt: row.createdAt,
        actor: {
          id: row.actor.id,
          name: row.actor.name ?? row.actor.phone,
          phone: row.actor.phone,
        },
        client: {
          id: row.client.id,
          name: row.client.name ?? row.client.phone,
          phone: row.client.phone,
        },
      })),
      total,
      page: params.page,
      limit: params.limit,
    };
  }

  private async recordAudit(
    actorId: string,
    clientId: string,
    action: string,
    meta?: Prisma.InputJsonValue,
  ) {
    await this.prisma.staffAuditLog.create({
      data: {
        actorId,
        clientId,
        action,
        meta: meta ?? Prisma.JsonNull,
      },
    });
  }

  private async assertClientAccess(actor: JwtPayload, clientId: string) {
    await this.requireClient(clientId);
    const roles = [actor.role, ...(actor.extraRoles ?? [])];
    if (canSeeContactPhone(roles) || roles.includes(UserRole.admin)) {
      return;
    }

    const linked = await this.prisma.user.findFirst({
      where: {
        id: clientId,
        ...clientLinkedToStaffWhere(actor.sub),
      },
      select: { id: true },
    });
    if (!linked) {
      throw new ForbiddenException('No access to this client');
    }
  }

  private async requireClient(clientId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: clientId },
      select: {
        id: true,
        phone: true,
        name: true,
        email: true,
        birthDate: true,
        role: true,
        createdAt: true,
      },
    });

    if (!user || user.role !== UserRole.client) {
      throw new NotFoundException('Client not found');
    }

    return user;
  }

  private async projectCartCounts(userIds: string[]) {
    const counts = new Map<string, number>();
    if (userIds.length === 0) return counts;
    const wanted = new Set(userIds);
    const carts = await this.prisma.cart.findMany({
      where: {
        project: {
          isShowcase: false,
          OR: [
            { userId: { in: userIds } },
            { members: { some: { userId: { in: userIds } } } },
          ],
        },
      },
      select: {
        project: {
          select: {
            userId: true,
            members: { select: { userId: true } },
          },
        },
        _count: { select: { items: true } },
      },
    });
    for (const cart of carts) {
      const project = cart.project;
      if (!project) continue;
      const targets = new Set<string>();
      if (wanted.has(project.userId)) targets.add(project.userId);
      for (const member of project.members) {
        if (wanted.has(member.userId)) targets.add(member.userId);
      }
      for (const userId of targets) {
        counts.set(userId, (counts.get(userId) ?? 0) + cart._count.items);
      }
    }
    return counts;
  }

  private formatClientSummary(
    user: {
      id: string;
      phone: string;
      name: string | null;
      email: string | null;
      birthDate: Date | null;
      createdAt: Date;
      _count: { clientProjects: number; orders: number };
    },
    cartItemsCount: number,
  ) {
    return {
      id: user.id,
      phone: user.phone,
      name: user.name,
      email: user.email,
      createdAt: user.createdAt,
      projectsCount: user._count.clientProjects,
      ordersCount: user._count.orders,
      cartItemsCount,
    };
  }

  async getClientSupportChat(actor: JwtPayload, clientId: string) {
    await this.assertClientAccess(actor, clientId);
    return this.chatService.openClientSupportChat(actor.sub, clientId);
  }

  async listRoster(role: 'designer' | 'surveyor') {
    const users = await this.prisma.user.findMany({
      where: {
        OR: [{ role }, { extraRoles: { has: role } }],
      },
      select: { id: true, name: true, phone: true, role: true },
      orderBy: [{ name: 'asc' }, { phone: 'asc' }],
    });

    return {
      items: users.map((user) => ({
        id: user.id,
        name: user.name?.trim() || user.phone,
        phone: user.phone,
        role: user.role,
      })),
    };
  }

  async assignProjectStaff(
    actor: JwtPayload,
    projectId: string,
    dto: { designerId?: string | null; surveyorId?: string | null },
  ) {
    if (!canSeeContactPhone([actor.role, ...(actor.extraRoles ?? [])])) {
      throw new ForbiddenException('Only managers and admins can assign staff');
    }

    const project = await this.prisma.project.findFirst({
      where: { id: projectId, isShowcase: false },
      select: { id: true, userId: true },
    });
    if (!project) {
      throw new NotFoundException('Project not found');
    }

    await this.assertClientAccess(actor, project.userId);

    const assigned = await this.chatService.assignToClientProject({
      actorId: actor.sub,
      projectId,
      designerId: dto.designerId,
      surveyorId: dto.surveyorId,
    });
    void this.liveSync.publish(projectId, 'project');
    return assigned;
  }

  async inviteByPhone(
    actor: { sub: string; role: UserRole; extraRoles?: UserRole[] },
    phoneRaw: string,
    name?: string,
  ) {
    if (!canSeeContactPhone([actor.role, ...(actor.extraRoles ?? [])])) {
      throw new ForbiddenException('Only managers and admins can invite');
    }

    const digits = phoneRaw.replace(/\D/g, '');
    let phone = phoneRaw;
    if (digits.length === 11 && digits.startsWith('8')) {
      phone = `+7${digits.slice(1)}`;
    } else if (digits.length === 11 && digits.startsWith('7')) {
      phone = `+${digits}`;
    } else if (digits.length === 10) {
      phone = `+7${digits}`;
    }
    if (!/^\+7\d{10}$/.test(phone)) {
      throw new BadRequestException('Invalid phone');
    }

    const user = await this.prisma.user.upsert({
      where: { phone },
      update: name?.trim() ? { name: name.trim() } : {},
      create: {
        phone,
        name: name?.trim() || null,
        role: UserRole.client,
      },
    });

    await this.chatService.ensureDavartChat(user.id);

    return { id: user.id, phone: user.phone, invited: true };
  }
}
