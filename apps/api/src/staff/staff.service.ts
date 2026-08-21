import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, UserRole } from '@prisma/client';
import { CartService } from '../commerce/cart.service';
import { OrdersService } from '../commerce/orders.service';
import { PrismaService } from '../prisma/prisma.service';
import { ProjectsService } from '../projects/projects.service';
import { PushService } from '../push/push.service';
import { CreateProjectDto } from '../projects/dto/projects.dto';
import { CreateAddressDto } from '../users/dto/users.dto';
import { UsersService } from '../users/users.service';

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

    return {
      items: items.map((user) => this.formatClientSummary(user)),
      total,
      page: params.page,
      limit: params.limit,
    };
  }

  async getClient(clientId: string) {
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
    clientId: string,
    dto: { name?: string; email?: string; birthDate?: string },
  ) {
    await this.requireClient(clientId);

    const user = await this.prisma.user.update({
      where: { id: clientId },
      data: {
        name: dto.name,
        email: dto.email,
        birthDate: dto.birthDate ? new Date(dto.birthDate) : undefined,
      },
      select: {
        id: true,
        phone: true,
        name: true,
        email: true,
        birthDate: true,
        createdAt: true,
      },
    });

    return this.getClient(user.id);
  }

  async listAddresses(clientId: string) {
    await this.requireClient(clientId);
    return this.usersService.listAddresses(clientId);
  }

  async listProjects(clientId: string) {
    await this.requireClient(clientId);
    return this.projectsService.listForUser(clientId);
  }

  async createProject(clientId: string, dto: CreateProjectDto) {
    await this.requireClient(clientId);
    return this.projectsService.create(clientId, dto);
  }

  async getProject(clientId: string, projectId: string) {
    await this.requireClient(clientId);
    return this.projectsService.getById(clientId, projectId);
  }

  async getBrief(clientId: string, projectId: string) {
    await this.requireClient(clientId);
    const brief = await this.projectsService.getBrief(clientId, projectId);
    // Staff always sees brief as locked (read-only contract for 13B).
    return { ...brief, isLocked: true };
  }

  async getBriefPdf(clientId: string, projectId: string) {
    await this.requireClient(clientId);
    return this.projectsService.generateBriefPdf(clientId, projectId);
  }

  async getCart(actorId: string, actorRole: UserRole, projectId: string) {
    return this.cartService.getCart(projectId, actorId, actorRole);
  }

  async addCartItem(
    actorId: string,
    actorRole: UserRole,
    projectId: string,
    productId: string,
    quantity: number,
  ) {
    const cart = await this.cartService.addItem(
      projectId,
      actorId,
      actorRole,
      productId,
      quantity,
    );

    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      select: { name: true },
    });

    const clientId = cart.ownerUserId;

    await this.recordAudit(actorId, clientId, 'cart.add', {
      productId,
      quantity,
      productName: product?.name ?? null,
      projectId,
    });

    await this.pushService.sendToUser(clientId, {
      title: 'Корзина обновлена',
      body: product?.name
        ? `Команда Davart добавила «${product.name}» в корзину проекта`
        : 'Команда Davart добавила товар в корзину проекта',
      data: { type: 'cart', clientId, projectId },
    });

    return cart;
  }

  async updateCartItem(
    actorId: string,
    actorRole: UserRole,
    projectId: string,
    itemId: string,
    quantity: number,
  ) {
    const cart = await this.cartService.updateItem(
      projectId,
      actorId,
      actorRole,
      itemId,
      quantity,
    );
    await this.recordAudit(actorId, cart.ownerUserId, 'cart.update', {
      itemId,
      quantity,
      projectId,
    });
    return cart;
  }

  async removeCartItem(
    actorId: string,
    actorRole: UserRole,
    projectId: string,
    itemId: string,
  ) {
    const cart = await this.cartService.removeItem(
      projectId,
      actorId,
      actorRole,
      itemId,
    );
    await this.recordAudit(actorId, cart.ownerUserId, 'cart.remove', {
      itemId,
      projectId,
    });
    return cart;
  }

  async clearCart(actorId: string, actorRole: UserRole, projectId: string) {
    const cart = await this.cartService.clearCart(
      projectId,
      actorId,
      actorRole,
    );
    await this.recordAudit(actorId, cart.ownerUserId, 'cart.clear', {
      projectId,
    });
    return cart;
  }

  async createOrder(
    actorId: string,
    actorRole: UserRole,
    projectId: string,
    address: string,
    comment?: string,
    cartItemIds?: string[],
  ) {
    const order = await this.ordersService.createFromCart(
      actorId,
      actorRole,
      projectId,
      address,
      comment,
      cartItemIds,
    );

    const clientId = order.userId ?? (await this.ownerIdForProject(projectId));

    await this.recordAudit(actorId, clientId, 'order.create', {
      orderId: order.id,
      totalAmount: order.totalAmount,
      address,
      projectId,
    });

    await this.pushService.sendToUser(clientId, {
      title: 'Заказ оформлен',
      body: `Команда Davart оформила заказ на ${order.totalAmount.toLocaleString('ru-RU')} ₽`,
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

  async listOrders(clientId: string) {
    await this.requireClient(clientId);
    return this.ordersService.list(clientId);
  }

  async getOrder(clientId: string, orderId: string) {
    await this.requireClient(clientId);
    return this.ordersService.getById(clientId, orderId);
  }

  async createAddress(
    actorId: string,
    clientId: string,
    dto: CreateAddressDto,
  ) {
    await this.requireClient(clientId);
    const address = await this.usersService.createAddress(clientId, dto);
    await this.recordAudit(actorId, clientId, 'address.create', {
      addressId: address.id,
      city: dto.city,
    });
    return address;
  }

  async listAudit(params: { page: number; limit: number; clientId?: string }) {
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

  private formatClientSummary(user: {
    id: string;
    phone: string;
    name: string | null;
    email: string | null;
    birthDate: Date | null;
    createdAt: Date;
    _count: { clientProjects: number; orders: number };
  }) {
    return {
      id: user.id,
      phone: user.phone,
      name: user.name,
      email: user.email,
      createdAt: user.createdAt,
      projectsCount: user._count.clientProjects,
      ordersCount: user._count.orders,
      cartItemsCount: 0,
    };
  }
}
