import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { OrderStatus, UserRole } from '@prisma/client';
import { isStudioRole } from '../auth/roles';
import { PushService } from '../push/push.service';
import { PrismaService } from '../prisma/prisma.service';
import { TelegramService } from '../telegram/telegram.service';
import { CartService } from './cart.service';

const ORDER_STATUS_LABELS: Record<OrderStatus, string> = {
  created: 'Оформлен',
  confirmed: 'Согласован',
  assembling: 'Собирается',
  shipping: 'В пути',
  delivered: 'Доставлен',
};

@Injectable()
export class OrdersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cartService: CartService,
    private readonly pushService: PushService,
    private readonly telegram: TelegramService,
  ) {}

  async createFromCart(
    userId: string,
    actorRole: UserRole,
    projectId: string,
    address: string,
    comment?: string,
    cartItemIds?: string[],
    extraRoles: UserRole[] = [],
  ) {
    await this.cartService.assertProjectCartAccess(projectId, userId, [
      actorRole,
      ...extraRoles,
    ]);

    if (!cartItemIds?.length) {
      throw new BadRequestException('cartItemIds is required');
    }

    const uniqueIds = [...new Set(cartItemIds)];
    const cart = await this.cartService.getCartSnapshot(projectId);
    const selected = cart.items.filter((item) => uniqueIds.includes(item.id));

    if (selected.length !== uniqueIds.length) {
      throw new BadRequestException('Some cart items were not found');
    }

    if (selected.some((item) => item.locked)) {
      throw new BadRequestException('Cannot order locked cart items');
    }

    if (selected.length === 0) {
      throw new BadRequestException('Cart selection is empty');
    }

    const totalAmount = selected.reduce((sum, item) => sum + item.subtotal, 0);
    const orderUserId = isStudioRole(actorRole) ? cart.ownerUserId : userId;

    const order = await this.prisma.$transaction(async (tx) => {
      const created = await tx.order.create({
        data: {
          userId: orderUserId,
          projectId,
          address,
          comment,
          totalAmount,
          status: OrderStatus.created,
          items: {
            create: selected.map((item) => ({
              productId: item.product.id,
              quantity: item.quantity,
              price: item.product.price,
              name: item.product.name,
              sku: item.product.sku,
            })),
          },
          statusHistory: {
            create: { status: OrderStatus.created },
          },
        },
        include: {
          items: true,
          statusHistory: { orderBy: { createdAt: 'asc' } },
        },
      });

      await tx.cartItem.updateMany({
        where: {
          id: { in: selected.map((item) => item.id) },
          lockedAt: null,
        },
        data: {
          lockedAt: new Date(),
          lockedByOrderId: created.id,
        },
      });

      return created;
    });

    const formatted = this.formatOrder(order);

    const client = await this.prisma.user.findUnique({
      where: { id: orderUserId },
      select: { id: true, name: true, phone: true },
    });

    // Alert is best-effort: a Telegram outage must not fail checkout.
    void this.telegram.notifyOrderCreated({
      orderId: formatted.id,
      projectId,
      projectName: cart.projectName,
      clientId: orderUserId,
      clientName: client?.name ?? null,
      clientPhone: client?.phone ?? '',
      address,
      totalAmount: formatted.totalAmount,
      items: selected.map((item) => ({
        name: item.product.name,
        sku: item.product.sku,
        quantity: item.quantity,
        price: item.product.price,
      })),
    });

    return formatted;
  }

  async list(userId: string) {
    const orders = await this.prisma.order.findMany({
      where: { userId },
      include: {
        items: true,
        statusHistory: { orderBy: { createdAt: 'asc' } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return orders.map((order) => this.formatOrder(order));
  }

  async getById(userId: string, orderId: string) {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, userId },
      include: {
        items: true,
        statusHistory: { orderBy: { createdAt: 'asc' } },
      },
    });

    if (!order) {
      throw new NotFoundException('Order not found');
    }

    return this.formatOrder(order);
  }

  async updateStatus(orderId: string, status: OrderStatus) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: {
        items: true,
        statusHistory: { orderBy: { createdAt: 'asc' } },
      },
    });

    if (!order) {
      throw new NotFoundException('Order not found');
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const result = await tx.order.update({
        where: { id: orderId },
        data: { status },
        include: {
          items: true,
          statusHistory: { orderBy: { createdAt: 'asc' } },
        },
      });

      await tx.orderStatusHistory.create({
        data: { orderId, status },
      });

      return result;
    });

    const formatted = this.formatOrder(updated);

    await this.pushService.sendToUser(order.userId, {
      title: 'Статус заказа изменён',
      body: `Заказ #${orderId.slice(0, 8)}: ${formatted.statusLabel}`,
      data: { type: 'order', orderId },
    });

    return formatted;
  }

  private formatOrder(order: {
    id: string;
    userId: string;
    projectId?: string | null;
    status: OrderStatus;
    address: string;
    comment: string | null;
    totalAmount: { toString(): string } | number;
    createdAt: Date;
    updatedAt: Date;
    items: Array<{
      id: string;
      productId: string;
      quantity: number;
      price: { toString(): string } | number;
      name: string;
      sku: string;
    }>;
    statusHistory: Array<{
      id: string;
      status: OrderStatus;
      createdAt: Date;
    }>;
  }) {
    return {
      id: order.id,
      userId: order.userId,
      projectId: order.projectId ?? null,
      status: order.status,
      statusLabel: ORDER_STATUS_LABELS[order.status],
      address: order.address,
      comment: order.comment,
      totalAmount: Number(order.totalAmount),
      createdAt: order.createdAt,
      updatedAt: order.updatedAt,
      items: order.items.map((item) => ({
        id: item.id,
        productId: item.productId,
        quantity: item.quantity,
        price: Number(item.price),
        subtotal: Number(item.price) * item.quantity,
        name: item.name,
        sku: item.sku,
      })),
      statusHistory: order.statusHistory.map((entry) => ({
        id: entry.id,
        status: entry.status,
        statusLabel: ORDER_STATUS_LABELS[entry.status],
        createdAt: entry.createdAt,
      })),
    };
  }
}
