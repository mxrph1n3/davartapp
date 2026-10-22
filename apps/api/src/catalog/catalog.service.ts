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
import { resolveProductImageUrl } from './demo-product-image';

/** Characteristics worth showing in a list row, in this order. */
const LIST_ATTRIBUTE_KEYS = ['Размер', 'Поверхность', 'Материал', 'Цвет'];

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
  unit: true,
  sellByPack: true,
  packSize: true,
  packPieces: true,
  leadTimeMinDays: true,
  leadTimeMaxDays: true,
  collectionSlug: true,
  // Shown under the name in lists: size, surface, etc.
  attributes: {
    where: { key: { in: LIST_ATTRIBUTE_KEYS } },
    select: { key: true, value: true },
  },
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
  images: true,
  sourceUrl: true,
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

  /** Top-level tiles with their subcategories; counts include subcategories. */
  async getCategories() {
    const rows = await this.prisma.category.findMany({
      orderBy: { sortOrder: 'asc' },
      select: {
        id: true,
        name: true,
        slug: true,
        imageUrl: true,
        sortOrder: true,
        parentId: true,
        _count: { select: { products: true } },
      },
    });
    const children = new Map<string, typeof rows>();
    for (const row of rows) {
      if (!row.parentId) continue;
      children.set(row.parentId, [...(children.get(row.parentId) ?? []), row]);
    }
    const shape = (row: (typeof rows)[number]) => ({
      id: row.id,
      name: row.name,
      slug: row.slug,
      imageUrl: row.imageUrl,
      sortOrder: row.sortOrder,
      productCount: row._count.products,
    });
    return rows
      .filter((row) => !row.parentId)
      .map((top) => {
        const subs = (children.get(top.id) ?? []).map(shape);
        return {
          ...shape(top),
          productCount:
            top._count.products +
            subs.reduce((sum, c) => sum + c.productCount, 0),
          children: subs,
        };
      });
  }

  /** A category and its subcategories, so a tile shows everything inside it. */
  private async categoryScope(categoryId: string): Promise<string[]> {
    const subs = await this.prisma.category.findMany({
      where: { parentId: categoryId },
      select: { id: true },
    });
    return [categoryId, ...subs.map((c) => c.id)];
  }

  /** Filter options for a category (or the whole catalog): brands, price range and
   *  every characteristic present with its values and product counts. */
  async getFilterOptions(categoryId?: string) {
    const scope = categoryId ? await this.categoryScope(categoryId) : undefined;
    const productWhere: Prisma.ProductWhereInput = scope
      ? { categoryId: { in: scope } }
      : {};

    const [brands, attributes, priceAgg] = await Promise.all([
      this.prisma.brand.findMany({
        where: scope ? { products: { some: productWhere } } : undefined,
        orderBy: { name: 'asc' },
        select: { id: true, name: true, slug: true },
      }),
      this.prisma.productAttribute.groupBy({
        by: ['key', 'value'],
        where: scope ? { product: productWhere } : undefined,
        _count: { _all: true },
        orderBy: [{ key: 'asc' }, { value: 'asc' }],
      }),
      this.prisma.product.aggregate({
        where: productWhere,
        _min: { price: true },
        _max: { price: true },
      }),
    ]);

    const facets = new Map<string, Array<{ value: string; count: number }>>();
    for (const row of attributes) {
      facets.set(row.key, [
        ...(facets.get(row.key) ?? []),
        { value: row.value, count: row._count._all },
      ]);
    }
    // Free-text characteristics (descriptions, articles) make poor filters.
    const SKIP = new Set(['Описание', 'Артикул', 'Коллекция']);

    return {
      brands,
      // Kept for older app builds.
      materials: (facets.get('Материал') ?? []).map((v) => v.value),
      colors: (facets.get('Цвет') ?? []).map((v) => v.value),
      collections: [],
      attributes: [...facets.entries()]
        .filter(
          ([key, values]) =>
            !SKIP.has(key) && values.length > 1 && values.length <= 40,
        )
        .map(([key, values]) => ({ key, values })),
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
    // Browsing without text, characteristic filters, several brands and category trees go to
    // Postgres; Meilisearch is only for text search (its index may lag behind the database).
    if (
      !query.q?.trim() ||
      query.attr?.length ||
      query.brandIds ||
      query.categoryId
    ) {
      return this.searchWithPrisma(query);
    }
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

    return this.formatProductDetail(
      product,
      await this.relatedProducts(product),
    );
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
    const scope = query.categoryId
      ? await this.categoryScope(query.categoryId)
      : undefined;
    const where = this.buildPrismaWhere(query, scope);

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

  private buildPrismaWhere(
    query: SearchQueryDto,
    categoryScope?: string[],
  ): Prisma.ProductWhereInput {
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
    if (categoryScope) {
      and.push({ categoryId: { in: categoryScope } });
    } else if (query.categoryId) {
      and.push({ categoryId: query.categoryId });
    }
    if (query.brandId) and.push({ brandId: query.brandId });
    if (query.brandIds) {
      and.push({ brandId: { in: query.brandIds.split(',').filter(Boolean) } });
    }
    const byKey = new Map<string, string[]>();
    for (const pair of query.attr ?? []) {
      const i = pair.indexOf(':');
      if (i <= 0) continue;
      const key = pair.slice(0, i);
      byKey.set(key, [...(byKey.get(key) ?? []), pair.slice(i + 1)]);
    }
    for (const [key, values] of byKey) {
      and.push({ attributes: { some: { key, value: { in: values } } } });
    }
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
      imageUrl: resolveProductImageUrl({
        productId: product.id,
        categorySlug: product.category?.slug,
        imageUrl: product.imageUrl,
      }),
      description: product.description,
      inStock: product.inStock,
      isPopular: product.isPopular,
      unit: product.unit,
      sellByPack: product.sellByPack,
      packSize: product.packSize ? Number(product.packSize) : null,
      packPieces: product.packPieces,
      leadTimeMinDays: product.leadTimeMinDays,
      leadTimeMaxDays: product.leadTimeMaxDays,
      collectionSlug: product.collectionSlug,
      highlights: LIST_ATTRIBUTE_KEYS.flatMap((key) =>
        product.attributes.filter((a) => a.key === key).map((a) => a.value),
      ),
      category: product.category,
      brand: product.brand,
    };
  }

  private formatProductDetail(
    product: Prisma.ProductGetPayload<{ select: typeof productDetailSelect }>,
    related: { collection: unknown[]; similar: unknown[] },
  ) {
    const base = this.formatProductListItem(product);
    return {
      ...base,
      images: [base.imageUrl, ...product.images].filter(
        (url, i, all): url is string => !!url && all.indexOf(url) === i,
      ),
      createdAt: product.createdAt,
      attributes: product.attributes,
      collection: related.collection,
      similar: related.similar,
    };
  }

  /**
   * Same collection, plus «Похожие» — every product gets alternatives: first the same
   * subcategory at a similar price, then the same subcategory at any price, then the
   * neighbouring subcategories of the same tile. Empty only when the tile has nothing else.
   */
  private async relatedProducts(product: {
    id: string;
    collectionSlug: string | null;
    category: { id: string } | null;
    price: Prisma.Decimal;
  }) {
    const price = Number(product.price);
    const limit = 12;
    const collection = product.collectionSlug
      ? await this.prisma.product.findMany({
          where: {
            collectionSlug: product.collectionSlug,
            id: { not: product.id },
          },
          take: limit,
          orderBy: { isPopular: 'desc' },
          select: productListSelect,
        })
      : [];

    const similar: typeof collection = [];
    if (product.category) {
      const category = await this.prisma.category.findUnique({
        where: { id: product.category.id },
        select: { id: true, parentId: true },
      });
      const tileId = category?.parentId ?? category?.id;
      const tileScope = tileId ? await this.categoryScope(tileId) : [];
      const exclude = new Set([product.id, ...collection.map((p) => p.id)]);
      const tiers: Prisma.ProductWhereInput[] = [
        {
          categoryId: product.category.id,
          price: { gte: price * 0.5, lte: price * 1.6 },
        },
        { categoryId: product.category.id },
        { categoryId: { in: tileScope } },
      ];
      for (const where of tiers) {
        if (similar.length >= limit) break;
        const found = await this.prisma.product.findMany({
          where: { ...where, id: { notIn: [...exclude] } },
          take: limit - similar.length,
          orderBy: [{ inStock: 'desc' }, { isPopular: 'desc' }],
          select: productListSelect,
        });
        for (const p of found) {
          exclude.add(p.id);
          similar.push(p);
        }
      }
    }

    return {
      collection: collection.map((p) => this.formatProductListItem(p)),
      similar: similar.map((p) => this.formatProductListItem(p)),
    };
  }
}
