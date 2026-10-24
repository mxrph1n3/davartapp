import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { LiveSyncService } from '../live/live-sync.service';
import {
  canAccessAnyClientProject,
  staffAssignedToProjectWhere,
  userCanAccessProjectWhere,
  userProjectAccessWhere,
} from '../projects/project-access';
import { unitLinePrice } from './pack-price';
import { resolveProductImageUrl } from '../catalog/demo-product-image';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class CartService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly liveSync: LiveSyncService,
  ) {}

  async getCart(
    projectId: string | undefined,
    actorId: string,
    actorRole: UserRole,
    extraRoles: UserRole[] = [],
  ) {
    if (!projectId) {
      const cart = await this.getOrCreatePersonalCart(actorId);
      return this.formatCart(cart.id);
    }
    await this.assertProjectCartAccess(projectId, actorId, [
      actorRole,
      ...extraRoles,
    ]);
    const cart = await this.getOrCreateCart(projectId);
    return this.formatCart(cart.id);
  }

  /** Project carts the signed-in person can see. Personal cart is separate. */
  async listProjectCarts(actorId: string) {
    const carts = await this.prisma.cart.findMany({
      where: {
        projectId: { not: null },
        items: { some: {} },
        project: {
          AND: [userProjectAccessWhere(actorId), { isDraft: false }],
        },
      },
      select: { id: true },
      orderBy: { updatedAt: 'desc' },
    });
    return Promise.all(carts.map((cart) => this.formatCart(cart.id)));
  }

  async assignPersonalCart(
    actorId: string,
    actorRole: UserRole,
    projectId: string,
    extraRoles: UserRole[] = [],
    itemIds?: string[],
  ) {
    await this.assertProjectCartAccess(projectId, actorId, [
      actorRole,
      ...extraRoles,
    ]);
    const project = await this.prisma.project.findFirst({
      where: { id: projectId, isShowcase: false, isDraft: false },
      select: { id: true },
    });
    if (!project) {
      throw new BadRequestException(
        'Сначала отправьте анкету в разделе «Дизайн»',
      );
    }

    const personal = await this.prisma.cart.findUnique({
      where: { userId: actorId },
      include: { items: true },
    });
    const projectCart = await this.getOrCreateCart(projectId);
    if (!personal) {
      return this.formatCart(projectCart.id);
    }

    const chosen = itemIds == null ? null : new Set(itemIds);
    let moved = 0;
    await this.prisma.$transaction(async (tx) => {
      for (const item of personal.items) {
        if (item.lockedAt) continue;
        if (chosen && !chosen.has(item.id)) continue;
        moved += 1;
        const existing = await tx.cartItem.findUnique({
          where: {
            cartId_productId: {
              cartId: projectCart.id,
              productId: item.productId,
            },
          },
        });
        if (existing?.lockedAt) {
          throw new BadRequestException(
            'This product is locked in an order and cannot be changed',
          );
        }
        await tx.cartItem.upsert({
          where: {
            cartId_productId: {
              cartId: projectCart.id,
              productId: item.productId,
            },
          },
          update: { quantity: { increment: item.quantity } },
          create: {
            cartId: projectCart.id,
            productId: item.productId,
            quantity: item.quantity,
          },
        });
        await tx.cartItem.delete({ where: { id: item.id } });
      }
    });

    if (moved === 0) {
      throw new BadRequestException('Выберите позиции');
    }

    const formatted = await this.formatCart(projectCart.id);
    await this.announceProjectCart(projectId);
    return formatted;
  }

  async addItem(
    projectId: string | undefined,
    actorId: string,
    actorRole: UserRole,
    productId: string,
    quantity: number,
    extraRoles: UserRole[] = [],
  ) {
    if (!projectId) {
      const product = await this.prisma.product.findUnique({
        where: { id: productId },
      });
      if (!product) {
        throw new NotFoundException('Product not found');
      }
      const cart = await this.getOrCreatePersonalCart(actorId);
      await this.prisma.cartItem.upsert({
        where: { cartId_productId: { cartId: cart.id, productId } },
        update: { quantity: { increment: quantity } },
        create: { cartId: cart.id, productId, quantity },
      });
      return this.formatCart(cart.id);
    }

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

    const formatted = await this.formatCart(cart.id);
    await this.announceProjectCart(projectId);
    return formatted;
  }

  async updateItem(
    projectId: string | undefined,
    actorId: string,
    actorRole: UserRole,
    itemId: string,
    quantity: number,
    extraRoles: UserRole[] = [],
  ) {
    const cart = await this.cartForActor(
      projectId,
      actorId,
      actorRole,
      extraRoles,
    );
    const item = await this.prisma.cartItem.findFirst({
      where: { id: itemId, cartId: cart.id },
    });

    if (!item) {
      throw new NotFoundException('Cart item not found');
    }

    if (item.lockedAt) {
      throw new BadRequestException(
        'Cart item is locked and cannot be changed',
      );
    }

    await this.prisma.cartItem.update({
      where: { id: itemId },
      data: { quantity },
    });

    const formatted = await this.formatCart(cart.id);
    if (projectId) {
      await this.announceProjectCart(projectId);
    }
    return formatted;
  }

  async removeItem(
    projectId: string | undefined,
    actorId: string,
    actorRole: UserRole,
    itemId: string,
    extraRoles: UserRole[] = [],
  ) {
    const cart = await this.cartForActor(
      projectId,
      actorId,
      actorRole,
      extraRoles,
    );
    const item = await this.prisma.cartItem.findFirst({
      where: { id: itemId, cartId: cart.id },
    });

    if (!item) {
      throw new NotFoundException('Cart item not found');
    }

    if (item.lockedAt) {
      throw new BadRequestException(
        'Cart item is locked and cannot be removed',
      );
    }

    await this.prisma.cartItem.delete({ where: { id: itemId } });
    const formatted = await this.formatCart(cart.id);
    if (projectId) {
      await this.announceProjectCart(projectId);
    }
    return formatted;
  }

  /** «Удалить выбранные»: unlocked lines of one cart (personal or project). */
  async removeItems(
    projectId: string | undefined,
    actorId: string,
    actorRole: UserRole,
    itemIds: string[],
    extraRoles: UserRole[] = [],
  ) {
    const cart = await this.cartForActor(
      projectId,
      actorId,
      actorRole,
      extraRoles,
    );
    await this.prisma.cartItem.deleteMany({
      where: { id: { in: itemIds }, cartId: cart.id, lockedAt: null },
    });
    const formatted = await this.formatCart(cart.id);
    if (projectId) {
      await this.announceProjectCart(projectId);
    }
    return formatted;
  }

  async clearCart(
    projectId: string | undefined,
    actorId: string,
    actorRole: UserRole,
    extraRoles: UserRole[] = [],
  ) {
    const cart = await this.cartForActor(
      projectId,
      actorId,
      actorRole,
      extraRoles,
    );
    await this.prisma.cartItem.deleteMany({
      where: { cartId: cart.id, lockedAt: null },
    });
    const formatted = await this.formatCart(cart.id);
    if (projectId) {
      await this.announceProjectCart(projectId);
    }
    return formatted;
  }

  /** A client's personal cart, read-only for the studio (access is checked by the caller). */
  async getPersonalCartOf(userId: string) {
    const cart = await this.getOrCreatePersonalCart(userId);
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

  private async cartForActor(
    projectId: string | undefined,
    actorId: string,
    actorRole: UserRole,
    extraRoles: UserRole[],
  ) {
    if (!projectId) {
      return this.getOrCreatePersonalCart(actorId);
    }
    await this.assertProjectCartAccess(projectId, actorId, [
      actorRole,
      ...extraRoles,
    ]);
    return this.getOrCreateCart(projectId);
  }

  /**
   * Live refresh for everyone who has the project cart open. No push per product:
   * the designer tells the client in the chat when the cart (подборка) is ready.
   */
  private async announceProjectCart(projectId: string) {
    await this.liveSync.publish(projectId, 'cart');
  }

  private async getOrCreatePersonalCart(userId: string) {
    return this.prisma.cart.upsert({
      where: { userId },
      update: {},
      create: { userId },
    });
  }

  private async getOrCreateCart(projectId: string) {
    return this.prisma.cart.upsert({
      where: { projectId },
      update: {},
      create: { projectId },
    });
  }

  private async formatCart(cartId: string) {
    await this.prisma.cartItem.deleteMany({
      where: {
        cartId,
        OR: [{ lockedAt: { not: null } }, { lockedByOrderId: { not: null } }],
      },
    });

    const cart = await this.prisma.cart.findUnique({
      where: { id: cartId },
      include: {
        project: { select: { id: true, name: true, userId: true } },
        items: {
          where: { lockedAt: null, lockedByOrderId: null },
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
                unit: true,
                sellByPack: true,
                packSize: true,
                packPieces: true,
                leadTimeMinDays: true,
                leadTimeMaxDays: true,
                category: { select: { slug: true } },
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
      subtotal: unitLinePrice(item.product) * item.quantity,
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
        imageUrl: resolveProductImageUrl({
          productId: item.product.id,
          categorySlug: item.product.category?.slug,
          imageUrl: item.product.imageUrl,
        }),
        inStock: item.product.inStock,
        unit: item.product.unit,
        sellByPack: item.product.sellByPack,
        packSize: item.product.packSize ? Number(item.product.packSize) : null,
        packPieces: item.product.packPieces,
        leadTimeMinDays: item.product.leadTimeMinDays,
        leadTimeMaxDays: item.product.leadTimeMaxDays,
      },
    }));

    const unlocked = items.filter((item) => !item.locked);
    const total = unlocked.reduce((sum, item) => sum + item.subtotal, 0);
    const itemCount = unlocked.reduce((sum, item) => sum + item.quantity, 0);
    const ownerUserId = cart.project?.userId ?? cart.userId;
    if (!ownerUserId) {
      throw new NotFoundException('Cart owner not found');
    }

    return {
      projectId: cart.projectId,
      projectName: cart.project?.name ?? '',
      ownerUserId,
      items: unlocked,
      total,
      itemCount,
    };
  }
}
