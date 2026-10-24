import {
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
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
  getFilters(@Query('categoryId') categoryId?: string) {
    return this.catalogService.getFilterOptions(categoryId);
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
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.admin)
  async ingestItalon() {
    assertDevEndpointsAllowed();
    return this.catalogService.ingestItalon();
  }

  @Post('ingest/kerama')
  @HttpCode(200)
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.admin)
  async ingestKerama() {
    assertDevEndpointsAllowed();
    return this.catalogService.ingestKerama();
  }

  @Post('reindex')
  @HttpCode(200)
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.admin)
  async reindex() {
    assertDevEndpointsAllowed();

    const count = await this.catalogService.reindexProducts();
    return { indexed: count };
  }
}
