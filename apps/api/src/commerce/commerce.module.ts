import { Module } from '@nestjs/common';
import { TelegramModule } from '../telegram/telegram.module';
import { CartController } from './cart.controller';
import { CartService } from './cart.service';
import { FavoritesController } from './favorites.controller';
import { FavoritesService } from './favorites.service';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';

@Module({
  imports: [TelegramModule],
  controllers: [CartController, FavoritesController, OrdersController],
  providers: [CartService, FavoritesService, OrdersService],
  exports: [CartService, FavoritesService, OrdersService],
})
export class CommerceModule {}
