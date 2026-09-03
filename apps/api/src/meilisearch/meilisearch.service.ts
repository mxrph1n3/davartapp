import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Meilisearch, Index } from 'meilisearch';
import { ProductSort } from '../catalog/dto/search-query.dto';

export interface ProductSearchDocument {
  id: string;
  name: string;
  sku: string;
  description: string | null;
  price: number;
  categoryId: string;
  categoryName: string;
  brandId: string | null;
  brandName: string | null;
  material: string | null;
  color: string | null;
  collection: string | null;
  collectionSlug: string | null;
  inStock: boolean;
  isPopular: boolean;
  hasDiscount: boolean;
  createdAt: number;
}

export interface SearchParams {
  q?: string;
  categoryId?: string;
  brandId?: string;
  minPrice?: number;
  maxPrice?: number;
  material?: string;
  color?: string;
  collection?: string;
  inStock?: boolean;
  sort?: ProductSort;
  page?: number;
  limit?: number;
}

export interface SearchIdsResult {
  ids: string[];
  total: number;
  page: number;
  totalPages: number;
}

@Injectable()
export class MeilisearchService implements OnModuleInit {
  private readonly logger = new Logger(MeilisearchService.name);
  private client: Meilisearch | null = null;
  private productsIndex: Index<ProductSearchDocument> | null = null;

  constructor(private readonly configService: ConfigService) {}

  async onModuleInit() {
    const host = this.configService.get<string>('MEILISEARCH_HOST');
    const apiKey = this.configService.get<string>('MEILISEARCH_API_KEY');

    if (!host) {
      this.logger.warn('MEILISEARCH_HOST is not set, search indexing disabled');
      return;
    }

    try {
      this.client = new Meilisearch({ host, apiKey });
      const productsIndex = this.client.index('products');
      this.productsIndex = productsIndex;
      await productsIndex.updateFilterableAttributes([
        'categoryId',
        'brandId',
        'material',
        'color',
        'collection',
        'collectionSlug',
        'inStock',
        'hasDiscount',
        'price',
      ]);
      await productsIndex.updateSortableAttributes([
        'price',
        'createdAt',
        'isPopular',
        'inStock',
      ]);
      await productsIndex.updateSearchableAttributes([
        'name',
        'sku',
        'description',
        'brandName',
        'categoryName',
        'material',
        'color',
        'collection',
      ]);
      this.logger.log('Meilisearch connected');
    } catch (error) {
      this.logger.warn(
        `Meilisearch unavailable: ${error instanceof Error ? error.message : 'unknown error'}`,
      );
    }
  }

  async indexProducts(documents: ProductSearchDocument[]): Promise<void> {
    if (!this.productsIndex || documents.length === 0) return;

    await this.productsIndex.addDocuments(documents, { primaryKey: 'id' });
  }

  async searchProductIds(
    params: SearchParams,
  ): Promise<SearchIdsResult | null> {
    if (!this.productsIndex) return null;

    const page = params.page ?? 1;
    const limit = params.limit ?? 20;
    const filters = this.buildFilters(params);
    const sort = this.buildSort(params.sort);

    const result = await this.productsIndex.search(params.q ?? '', {
      filter: filters.length > 0 ? filters : undefined,
      sort,
      limit,
      offset: (page - 1) * limit,
    });

    return {
      ids: result.hits.map((hit) => hit.id),
      total: result.estimatedTotalHits ?? result.hits.length,
      page,
      totalPages: Math.ceil(
        (result.estimatedTotalHits ?? result.hits.length) / limit,
      ),
    };
  }

  isAvailable(): boolean {
    return this.productsIndex !== null;
  }

  async health(): Promise<void> {
    if (!this.client) {
      throw new Error('Meilisearch is not configured');
    }
    await this.client.health();
  }

  private buildFilters(params: SearchParams): string[] {
    const filters: string[] = [];

    if (params.categoryId) {
      filters.push(`categoryId = "${params.categoryId}"`);
    }
    if (params.brandId) {
      filters.push(`brandId = "${params.brandId}"`);
    }
    if (params.material) {
      filters.push(`material = "${params.material}"`);
    }
    if (params.color) {
      filters.push(`color = "${params.color}"`);
    }
    if (params.collection) {
      filters.push(
        `collectionSlug = "${params.collection}" OR collection = "${params.collection}"`,
      );
    }
    if (params.minPrice !== undefined) {
      filters.push(`price >= ${params.minPrice}`);
    }
    if (params.maxPrice !== undefined) {
      filters.push(`price <= ${params.maxPrice}`);
    }
    if (params.inStock !== undefined) {
      filters.push(`inStock = ${params.inStock}`);
    }
    if (params.sort === ProductSort.DISCOUNT) {
      filters.push('hasDiscount = true');
    }

    return filters;
  }

  private buildSort(sort?: ProductSort): string[] {
    switch (sort) {
      case ProductSort.PRICE_ASC:
        return ['price:asc'];
      case ProductSort.PRICE_DESC:
        return ['price:desc'];
      case ProductSort.NEW:
        return ['createdAt:desc'];
      case ProductSort.STOCK:
        return ['inStock:desc', 'isPopular:desc'];
      case ProductSort.DISCOUNT:
        return ['price:asc'];
      case ProductSort.POPULAR:
      default:
        return ['isPopular:desc', 'createdAt:desc'];
    }
  }
}
