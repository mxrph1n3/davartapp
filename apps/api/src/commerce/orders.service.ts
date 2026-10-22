import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { OrderStatus, UserRole } from '@prisma/client';
import { isStudioRole } from '../auth/roles';
import { LiveSyncService } from '../live/live-sync.service';
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
    private readonly liveSync: LiveSyncService,
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
    const visibleIds = new Set(cart.items.map((item) => item.id));
    if (uniqueIds.some((id) => !visibleIds.has(id))) {
      throw new BadRequestException('Some cart items were not found');
    }

    const orderUserId = isStudioRole(actorRole) ? cart.ownerUserId : userId;

    const order = await this.prisma.$transaction(async (tx) => {
      const projectCart = await tx.cart.findUnique({
        where: { projectId },
        select: { id: true },
      });
      if (!projectCart) {
        throw new NotFoundException('Cart not found');
      }

      const lines = await tx.cartItem.findMany({
        where: {
          id: { in: uniqueIds },
          cartId: projectCart.id,
          lockedAt: null,
          lockedByOrderId: null,
        },
        include: {
          product: {
            select: { id: true, name: true, sku: true, price: true },
          },
        },
      });

      if (lines.length !== uniqueIds.length) {
        throw new BadRequestException('Some cart items were not found');
      }

      const totalAmount = lines.reduce(
        (sum, item) => sum + Number(item.product.price) * item.quantity,
        0,
      );

      const created = await tx.order.create({
        data: {
          userId: orderUserId,
          projectId,
          address,
          comment,
          totalAmount,
          status: OrderStatus.created,
          items: {
            create: lines.map((item) => ({
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

      await tx.cartItem.deleteMany({
        where: {
          id: { in: lines.map((item) => item.id) },
          cartId: projectCart.id,
          lockedAt: null,
          lockedByOrderId: null,
        },
      });

      return { created, lines };
    });

    const formatted = this.formatOrder(order.created);

    const client = await this.prisma.user.findUnique({
      where: { id: orderUserId },
      select: { id: true, name: true, phone: true },
    });

    void this.liveSync.publish(projectId, 'order', { orderId: formatted.id });
    void this.liveSync.publish(projectId, 'cart');

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
      items: order.lines.map((item) => ({
        name: item.product.name,
        sku: item.product.sku,
        quantity: item.quantity,
        price: Number(item.product.price),
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

    if (order.projectId) {
      void this.liveSync.publish(order.projectId, 'order', { orderId });
    }
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
