import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MessageType } from '@prisma/client';
import type { TelegramOrderAlert } from '../telegram/telegram.service';
import { ChatDeliveryService } from './chat-delivery.service';
import { ChatService } from './chat.service';

/**
 * New orders land in the studio's «Заказы» group chat inside the app
 * (instead of Telegram, decision of 24.10.2026). The chat and its sender —
 * a service account that sits in it — are set by ORDERS_CHAT_ID and
 * ORDERS_CHAT_SENDER_ID; without them the alert is only logged.
 */
@Injectable()
export class OrdersChatService {
  private readonly logger = new Logger(OrdersChatService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly chatService: ChatService,
    private readonly delivery: ChatDeliveryService,
  ) {}

  async notifyOrderCreated(alert: TelegramOrderAlert): Promise<void> {
    const chatId = this.config.get<string>('ORDERS_CHAT_ID')?.trim();
    const senderId = this.config.get<string>('ORDERS_CHAT_SENDER_ID')?.trim();
    const text = this.format(alert);
    if (!chatId || !senderId) {
      this.logger.log(`[ORDERS CHAT OFF] ${text}`);
      return;
    }

    try {
      const message = await this.chatService.sendMessage(senderId, chatId, {
        type: MessageType.text,
        content: text,
      });
      await this.delivery.publishLive(senderId, chatId, message);
    } catch (error) {
      // Checkout already succeeded; the alert must never fail it.
      this.logger.warn(
        `Order ${alert.orderId} not posted to orders chat: ${error}`,
      );
    }
  }

  private format(alert: TelegramOrderAlert): string {
    const clientLabel = alert.clientName?.trim() || alert.clientPhone;
    const lines = alert.items.map(
      (item) =>
        `• ${item.name} × ${item.quantity} — ${item.price.toLocaleString('ru-RU')} ₽`,
    );

    return [
      'Новый заказ',
      alert.projectId
        ? `Проект: ${alert.projectName ?? ''}`
        : 'Из личной корзины (без проекта)',
      `Клиент: ${clientLabel} (${alert.clientPhone})`,
      `Адрес: ${alert.address}`,
      `Сумма: ${alert.totalAmount.toLocaleString('ru-RU')} ₽`,
      '',
      ...lines,
    ].join('\n');
  }
}
