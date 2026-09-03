import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { ProductSort, SearchQueryDto } from './dto/search-query.dto';
import { ingestItalonProducts } from './italon/italon-ingest';
import { fetchItalonCatalog } from './italon/italon-parser';
import { ingestKeramaFromSitemap } from './kerama/kerama-ingest';
import {
  MeilisearchService,
  ProductSearchDocument,
  SearchParams,
} from '../meilisearch/meilisearch.service';
import { PrismaService } from '../prisma/prisma.service';

const productListSelect = {
  id: true,
  name: true,
  slug: true,
  sku: true,
  price: true,
  compareAtPrice: true,
  imageUrl: true,
  description: true,
  inStock: true,
  isPopular: true,
  category: {
    select: { id: true, name: true, slug: true },
  },
  brand: {
    select: { id: true, name: true, slug: true },
  },
} satisfies Prisma.ProductSelect;

const productDetailSelect = {
  ...productListSelect,
  createdAt: true,
  attributes: {
    select: { key: true, value: true },
    orderBy: { key: 'asc' as const },
  },
} satisfies Prisma.ProductSelect;

@Injectable()
export class CatalogService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly meilisearch: MeilisearchService,
  ) {}

  getCategories() {
    return this.prisma.category.findMany({
      orderBy: { sortOrder: 'asc' },
      select: {
        id: true,
        name: true,
        slug: true,
        imageUrl: true,
        sortOrder: true,
        _count: { select: { products: true } },
      },
    });
  }

  async getFilterOptions() {
    const [brands, materials, colors, collections, priceAgg] =
      await Promise.all([
        this.prisma.brand.findMany({
          orderBy: { name: 'asc' },
          select: { id: true, name: true, slug: true },
        }),
        this.prisma.productAttribute.findMany({
          where: { key: 'Материал' },
          distinct: ['value'],
          select: { value: true },
          orderBy: { value: 'asc' },
        }),
        this.prisma.productAttribute.findMany({
          where: { key: 'Цвет' },
          distinct: ['value'],
          select: { value: true },
          orderBy: { value: 'asc' },
        }),
        this.prisma.productAttribute.findMany({
          where: { key: 'Коллекция' },
          distinct: ['value'],
          select: {
            value: true,
            product: { select: { collectionSlug: true } },
          },
          orderBy: { value: 'asc' },
        }),
        this.prisma.product.aggregate({
          _min: { price: true },
          _max: { price: true },
        }),
      ]);

    const collectionMap = new Map<string, { slug: string; name: string }>();
    for (const item of collections) {
      const slug = item.product.collectionSlug ?? item.value;
      if (!collectionMap.has(slug)) {
        collectionMap.set(slug, { slug, name: item.value });
      }
    }

    return {
      brands,
      materials: materials.map((item) => item.value),
      colors: colors.map((item) => item.value),
      collections: [...collectionMap.values()].sort((a, b) =>
        a.name.localeCompare(b.name, 'ru'),
      ),
      priceRange: {
        min: Number(priceAgg._min.price ?? 0),
        max: Number(priceAgg._max.price ?? 0),
      },
    };
  }

  async getProducts(categoryId?: string, page = 1, limit = 20) {
    const where: Prisma.ProductWhereInput = categoryId ? { categoryId } : {};
    const skip = (page - 1) * limit;

    const [items, total] = await Promise.all([
      this.prisma.product.findMany({
        where,
        skip,
        take: limit,
        orderBy: [{ isPopular: 'desc' }, { createdAt: 'desc' }],
        select: productListSelect,
      }),
      this.prisma.product.count({ where }),
    ]);

    return {
      items: items.map((item) => this.formatProductListItem(item)),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async searchProducts(query: SearchQueryDto) {
    const params: SearchParams = {
      q: query.q,
      categoryId: query.categoryId,
      brandId: query.brandId,
      minPrice: query.minPrice,
      maxPrice: query.maxPrice,
      material: query.material,
      color: query.color,
      collection: query.collection,
      inStock: query.inStock,
      sort: query.sort,
      page: query.page,
      limit: query.limit,
    };

    const meiliResult = await this.meilisearch.searchProductIds(params);

    if (meiliResult) {
      return this.buildProductsResponse(
        meiliResult.ids,
        meiliResult.page,
        query.limit ?? 20,
        meiliResult.total,
        meiliResult.totalPages,
      );
    }

    return this.searchWithPrisma(query);
  }

  async getProductById(id: string) {
    const product = await this.prisma.product.findUnique({
      where: { id },
      select: productDetailSelect,
    });

    if (!product) {
      throw new NotFoundException('Product not found');
    }

    return this.formatProductDetail(product);
  }

  async reindexProducts(): Promise<number> {
    const products = await this.prisma.product.findMany({
      include: {
        category: true,
        brand: true,
        attributes: true,
      },
    });

    const documents: ProductSearchDocument[] = products.map((product) => ({
      id: product.id,
      name: product.name,
      sku: product.sku,
      description: product.description,
      price: Number(product.price),
      categoryId: product.categoryId,
      categoryName: product.category.name,
      brandId: product.brandId,
      brandName: product.brand?.name ?? null,
      material:
        product.attributes.find((attr) => attr.key === 'Материал')?.value ??
        null,
      color:
        product.attributes.find((attr) => attr.key === 'Цвет')?.value ?? null,
      collection:
        product.attributes.find((attr) => attr.key === 'Коллекция')?.value ??
        null,
      collectionSlug: product.collectionSlug,
      inStock: product.inStock,
      isPopular: product.isPopular,
      hasDiscount: product.compareAtPrice !== null,
      createdAt: product.createdAt.getTime(),
    }));

    await this.meilisearch.indexProducts(documents);
    return documents.length;
  }

  async ingestItalon() {
    const products = await fetchItalonCatalog();
    const result = await ingestItalonProducts(this.prisma, products);
    const indexed = await this.reindexProducts();
    return { ...result, indexed };
  }

  async ingestKerama() {
    const result = await ingestKeramaFromSitemap(this.prisma);
    const indexed = await this.reindexProducts();
    return { ...result, indexed };
  }

  private async searchWithPrisma(query: SearchQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;
    const where = this.buildPrismaWhere(query);

    const [items, total] = await Promise.all([
      this.prisma.product.findMany({
        where,
        skip,
        take: limit,
        orderBy: this.buildPrismaOrder(query.sort),
        select: productListSelect,
      }),
      this.prisma.product.count({ where }),
    ]);

    return {
      items: items.map((item) => this.formatProductListItem(item)),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  private async buildProductsResponse(
    ids: string[],
    page: number,
    limit: number,
    total: number,
    totalPages: number,
  ) {
    if (ids.length === 0) {
      return {
        items: [],
        pagination: { page, limit, total, totalPages },
      };
    }

    const products = await this.prisma.product.findMany({
      where: { id: { in: ids } },
      select: productListSelect,
    });

    const productMap = new Map(
      products.map((product) => [product.id, product]),
    );
    const ordered = ids
      .map((id) => productMap.get(id))
      .filter((product): product is NonNullable<typeof product> => !!product);

    return {
      items: ordered.map((item) => this.formatProductListItem(item)),
      pagination: { page, limit, total, totalPages },
    };
  }

  private buildPrismaWhere(query: SearchQueryDto): Prisma.ProductWhereInput {
    const and: Prisma.ProductWhereInput[] = [];

    if (query.q) {
      and.push({
        OR: [
          { name: { contains: query.q, mode: 'insensitive' } },
          { description: { contains: query.q, mode: 'insensitive' } },
          { sku: { contains: query.q, mode: 'insensitive' } },
        ],
      });
    }
    if (query.categoryId) and.push({ categoryId: query.categoryId });
    if (query.brandId) and.push({ brandId: query.brandId });
    if (query.minPrice !== undefined) {
      and.push({ price: { gte: query.minPrice } });
    }
    if (query.maxPrice !== undefined) {
      and.push({ price: { lte: query.maxPrice } });
    }
    if (query.inStock !== undefined) and.push({ inStock: query.inStock });
    if (query.sort === ProductSort.DISCOUNT) {
      and.push({ compareAtPrice: { not: null } });
    }
    if (query.material) {
      and.push({
        attributes: { some: { key: 'Материал', value: query.material } },
      });
    }
    if (query.color) {
      and.push({
        attributes: { some: { key: 'Цвет', value: query.color } },
      });
    }
    if (query.collection) {
      and.push({
        OR: [
          { collectionSlug: query.collection },
          {
            attributes: {
              some: { key: 'Коллекция', value: query.collection },
            },
          },
        ],
      });
    }

    return and.length > 0 ? { AND: and } : {};
  }

  private buildPrismaOrder(
    sort?: ProductSort,
  ): Prisma.ProductOrderByWithRelationInput[] {
    switch (sort) {
      case ProductSort.PRICE_ASC:
        return [{ price: 'asc' }];
      case ProductSort.PRICE_DESC:
        return [{ price: 'desc' }];
      case ProductSort.NEW:
        return [{ createdAt: 'desc' }];
      case ProductSort.STOCK:
        return [{ inStock: 'desc' }, { isPopular: 'desc' }];
      case ProductSort.DISCOUNT:
        return [{ compareAtPrice: 'desc' }, { price: 'asc' }];
      case ProductSort.POPULAR:
      default:
        return [{ isPopular: 'desc' }, { createdAt: 'desc' }];
    }
  }

  private formatProductListItem(
    product: Prisma.ProductGetPayload<{ select: typeof productListSelect }>,
  ) {
    return {
      id: product.id,
      name: product.name,
      slug: product.slug,
      sku: product.sku,
      price: Number(product.price),
      compareAtPrice: product.compareAtPrice
        ? Number(product.compareAtPrice)
        : null,
      imageUrl: product.imageUrl,
      description: product.description,
      inStock: product.inStock,
      isPopular: product.isPopular,
      category: product.category,
      brand: product.brand,
    };
  }

  private formatProductDetail(
    product: Prisma.ProductGetPayload<{ select: typeof productDetailSelect }>,
  ) {
    return {
      ...this.formatProductListItem(product),
      createdAt: product.createdAt,
      attributes: product.attributes,
    };
  }
}
