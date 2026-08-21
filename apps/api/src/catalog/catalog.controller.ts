import { Controller, Get, HttpCode, Param, Post, Query } from '@nestjs/common';
import { assertDevEndpointsAllowed } from '../common/dev-endpoints';
import { CatalogService } from './catalog.service';
import { ProductIdParamDto, ProductsQueryDto } from './dto/products-query.dto';
import { SearchQueryDto } from './dto/search-query.dto';

@Controller('catalog')
export class CatalogController {
  constructor(private readonly catalogService: CatalogService) {}

  @Get('categories')
  getCategories() {
    return this.catalogService.getCategories();
  }

  @Get('filters')
  getFilters() {
    return this.catalogService.getFilterOptions();
  }

  @Get('search')
  search(@Query() query: SearchQueryDto) {
    return this.catalogService.searchProducts(query);
  }

  @Get('products')
  getProducts(@Query() query: ProductsQueryDto) {
    return this.catalogService.getProducts(
      query.categoryId,
      query.page,
      query.limit,
    );
  }

  @Get('products/:id')
  getProduct(@Param() params: ProductIdParamDto) {
    return this.catalogService.getProductById(params.id);
  }

  @Post('ingest/italon')
  @HttpCode(200)
  async ingestItalon() {
    assertDevEndpointsAllowed();
    return this.catalogService.ingestItalon();
  }

  @Post('ingest/kerama')
  @HttpCode(200)
  async ingestKerama() {
    assertDevEndpointsAllowed();
    return this.catalogService.ingestKerama();
  }

  @Post('reindex')
  @HttpCode(200)
  async reindex() {
    assertDevEndpointsAllowed();

    const count = await this.catalogService.reindexProducts();
    return { indexed: count };
  }
}
