import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import {
  canAccessAnyClientProject,
  staffAssignedToProjectWhere,
  userCanAccessProjectWhere,
} from '../projects/project-access';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class CartService {
  constructor(private readonly prisma: PrismaService) {}

  async getCart(
    projectId: string,
    actorId: string,
    actorRole: UserRole,
    extraRoles: UserRole[] = [],
  ) {
    await this.assertProjectCartAccess(projectId, actorId, [
      actorRole,
      ...extraRoles,
    ]);
    const cart = await this.getOrCreateCart(projectId);
    return this.formatCart(cart.id);
  }

  async addItem(
    projectId: string,
    actorId: string,
    actorRole: UserRole,
    productId: string,
    quantity: number,
    extraRoles: UserRole[] = [],
  ) {
    await this.assertProjectCartAccess(projectId, actorId, [
      actorRole,
      ...extraRoles,
    ]);

    const product = await this.prisma.product.findUnique({
      where: { id: productId },
    });

    if (!product) {
      throw new NotFoundException('Product not found');
    }

    const cart = await this.getOrCreateCart(projectId);
    const existing = await this.prisma.cartItem.findUnique({
      where: {
        cartId_productId: { cartId: cart.id, productId },
      },
    });

    if (existing?.lockedAt) {
      throw new BadRequestException(
        'This product is locked in an order and cannot be changed',
      );
    }

    await this.prisma.cartItem.upsert({
      where: {
        cartId_productId: { cartId: cart.id, productId },
      },
      update: {
        quantity: { increment: quantity },
      },
      create: {
        cartId: cart.id,
        productId,
        quantity,
      },
    });

    return this.formatCart(cart.id);
  }

  async updateItem(
    projectId: string,
    actorId: string,
    actorRole: UserRole,
    itemId: string,
    quantity: number,
    extraRoles: UserRole[] = [],
  ) {
    await this.assertProjectCartAccess(projectId, actorId, [
      actorRole,
      ...extraRoles,
    ]);
    const cart = await this.getOrCreateCart(projectId);
    const item = await this.prisma.cartItem.findFirst({
      where: { id: itemId, cartId: cart.id },
    });

    if (!item) {
      throw new NotFoundException('Cart item not found');
    }

    if (item.lockedAt) {
      throw new BadRequestException('Cart item is locked and cannot be changed');
    }

    await this.prisma.cartItem.update({
      where: { id: itemId },
      data: { quantity },
    });

    return this.formatCart(cart.id);
  }

  async removeItem(
    projectId: string,
    actorId: string,
    actorRole: UserRole,
    itemId: string,
    extraRoles: UserRole[] = [],
  ) {
    await this.assertProjectCartAccess(projectId, actorId, [
      actorRole,
      ...extraRoles,
    ]);
    const cart = await this.getOrCreateCart(projectId);
    const item = await this.prisma.cartItem.findFirst({
      where: { id: itemId, cartId: cart.id },
    });

    if (!item) {
      throw new NotFoundException('Cart item not found');
    }

    if (item.lockedAt) {
      throw new BadRequestException('Cart item is locked and cannot be removed');
    }

    await this.prisma.cartItem.delete({ where: { id: itemId } });
    return this.formatCart(cart.id);
  }

  async clearCart(
    projectId: string,
    actorId: string,
    actorRole: UserRole,
    extraRoles: UserRole[] = [],
  ) {
    await this.assertProjectCartAccess(projectId, actorId, [
      actorRole,
      ...extraRoles,
    ]);
    const cart = await this.getOrCreateCart(projectId);
    await this.prisma.cartItem.deleteMany({
      where: { cartId: cart.id, lockedAt: null },
    });
    return this.formatCart(cart.id);
  }

  /** Used by OrdersService inside a transaction-friendly flow. */
  async getCartSnapshot(projectId: string) {
    const cart = await this.getOrCreateCart(projectId);
    return this.formatCart(cart.id);
  }

  async assertProjectCartAccess(
    projectId: string,
    actorId: string,
    roles: UserRole[],
  ) {
    const asOwner = await this.prisma.project.findFirst({
      where: userCanAccessProjectWhere(actorId, projectId),
      select: { id: true },
    });
    if (asOwner) return;

    if (canAccessAnyClientProject(roles)) {
      const project = await this.prisma.project.findFirst({
        where: { id: projectId, isShowcase: false },
        select: { id: true },
      });
      if (!project) {
        throw new NotFoundException('Project not found');
      }
      return;
    }

    const assigned = await this.prisma.project.findFirst({
      where: {
        id: projectId,
        ...staffAssignedToProjectWhere(actorId),
      },
      select: { id: true },
    });
    if (assigned) return;

    throw new ForbiddenException('No access to this project cart');
  }

  private async getOrCreateCart(projectId: string) {
    return this.prisma.cart.upsert({
      where: { projectId },
      update: {},
      create: { projectId },
    });
  }

  private async formatCart(cartId: string) {
    const cart = await this.prisma.cart.findUnique({
      where: { id: cartId },
      include: {
        project: { select: { id: true, name: true, userId: true } },
        items: {
          include: {
            product: {
              select: {
                id: true,
                name: true,
                slug: true,
                sku: true,
                price: true,
                compareAtPrice: true,
                imageUrl: true,
                inStock: true,
              },
            },
          },
          orderBy: { createdAt: 'asc' },
        },
      },
    });

    if (!cart) {
      throw new NotFoundException('Cart not found');
    }

    const items = cart.items.map((item) => ({
      id: item.id,
      quantity: item.quantity,
      subtotal: Number(item.product.price) * item.quantity,
      locked: item.lockedAt != null,
      lockedAt: item.lockedAt,
      lockedByOrderId: item.lockedByOrderId,
      product: {
        id: item.product.id,
        name: item.product.name,
        slug: item.product.slug,
        sku: item.product.sku,
        price: Number(item.product.price),
        compareAtPrice: item.product.compareAtPrice
          ? Number(item.product.compareAtPrice)
          : null,
        imageUrl: item.product.imageUrl,
        inStock: item.product.inStock,
      },
    }));

    const unlocked = items.filter((item) => !item.locked);
    const total = unlocked.reduce((sum, item) => sum + item.subtotal, 0);
    const itemCount = unlocked.reduce((sum, item) => sum + item.quantity, 0);

    return {
      projectId: cart.projectId,
      projectName: cart.project.name,
      ownerUserId: cart.project.userId,
      items,
      total,
      itemCount,
    };
  }
}
