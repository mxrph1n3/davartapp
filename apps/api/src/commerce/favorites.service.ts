import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class FavoritesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string) {
    const favorites = await this.prisma.favorite.findMany({
      where: { userId },
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
            isPopular: true,
            category: { select: { id: true, name: true, slug: true } },
            brand: { select: { id: true, name: true, slug: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return favorites.map((favorite) => ({
      id: favorite.id,
      product: {
        ...favorite.product,
        price: Number(favorite.product.price),
        compareAtPrice: favorite.product.compareAtPrice
          ? Number(favorite.product.compareAtPrice)
          : null,
      },
    }));
  }

  async add(userId: string, productId: string) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
    });

    if (!product) {
      throw new NotFoundException('Product not found');
    }

    const existing = await this.prisma.favorite.findUnique({
      where: { userId_productId: { userId, productId } },
    });

    if (existing) {
      throw new ConflictException('Product already in favorites');
    }

    await this.prisma.favorite.create({ data: { userId, productId } });
    return { message: 'Added to favorites' };
  }

  async remove(userId: string, productId: string) {
    const favorite = await this.prisma.favorite.findUnique({
      where: { userId_productId: { userId, productId } },
    });

    if (!favorite) {
      throw new NotFoundException('Favorite not found');
    }

    await this.prisma.favorite.delete({ where: { id: favorite.id } });
    return { message: 'Removed from favorites' };
  }

  async isFavorite(userId: string, productId: string): Promise<boolean> {
    const favorite = await this.prisma.favorite.findUnique({
      where: { userId_productId: { userId, productId } },
    });
    return !!favorite;
  }
}
