import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { networkInterfaces } from 'os';
import { RedisService } from '../redis/redis.service';

const SUBSCRIBERS_KEY = 'telegram:alert_chats';

export type TelegramOrderAlert = {
  orderId: string;
  /** null — order from the client's personal cart (no project). */
  projectId: string | null;
  projectName: string | null;
  clientId: string;
  clientName: string | null;
  clientPhone: string;
  address: string;
  totalAmount: number;
  items: Array<{ name: string; sku: string; quantity: number; price: number }>;
};

type TelegramApiResult = {
  ok: boolean;
  description?: string;
  parameters?: { migrate_to_chat_id?: number };
};

type TelegramUpdate = {
  update_id: number;
  message?: {
    chat: { id: number; type: string };
    text?: string;
  };
  my_chat_member?: {
    chat: { id: number; type: string };
    new_chat_member: { status: string };
  };
};

type UrlButton = { text: string; url: string };

@Injectable()
export class TelegramService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(TelegramService.name);
  private offset = 0;
  private polling = false;

  constructor(
    private readonly config: ConfigService,
    private readonly redis: RedisService,
  ) {}

  async onModuleInit() {
    if (!this.token() || this.config.get('NODE_ENV') === 'test') {
      return;
    }
    try {
      await this.api('deleteWebhook', { drop_pending_updates: false });
      this.polling = true;
      void this.pollLoop().catch((error) => {
        this.logger.warn(
          `Telegram poll stopped: ${error instanceof Error ? error.message : error}`,
        );
      });
      this.logger.log('Telegram bot: одно уведомление о заказе');
    } catch (error) {
      this.logger.warn(
        `Telegram unavailable: ${error instanceof Error ? error.message : error}`,
      );
    }
  }

  async onModuleDestroy() {
    this.polling = false;
  }

  async notifyOrderCreated(alert: TelegramOrderAlert): Promise<void> {
    try {
      const text = this.formatOrderAlert(alert);
      const keyboard = this.orderKeyboard(alert);
      const chats = await this.recipientChatIds();

      if (
        !this.token() ||
        chats.length === 0 ||
        this.config.get('NODE_ENV') === 'test'
      ) {
        this.logger.log(`[MOCK TELEGRAM]\n${text}`);
        return;
      }

      const sent = new Set<string>();
      for (const chatId of chats) {
        await this.sendMessage(chatId, text, keyboard, sent);
      }
    } catch (error) {
      this.logger.error(
        `Telegram alert failed: ${error instanceof Error ? error.message : error}`,
      );
    }
  }

  orderAppUrl(clientId: string, orderId: string): string {
    return `davart://staff/clients/${clientId}/orders/${orderId}`;
  }

  orderWebUrl(clientId: string, orderId: string): string | undefined {
    const crm = this.config.get<string>('CRM_WEB_URL')?.trim();
    if (crm) {
      return `${crm.replace(/\/$/, '')}/clients/${clientId}/orders/${orderId}`;
    }
    const base = this.publicBase();
    if (!base) return undefined;
    return `${base}/clients/${clientId}/orders/${orderId}`;
  }

  private token(): string | undefined {
    const value = this.config.get<string>('TELEGRAM_BOT_TOKEN')?.trim();
    return value || undefined;
  }

  private publicBase(): string | undefined {
    const configured =
      this.config.get<string>('APP_PUBLIC_URL')?.trim() ||
      this.config.get<string>('TELEGRAM_APP_URL')?.trim();
    if (configured) return configured.replace(/\/$/, '');

    const port = this.config.get<string>('PORT')?.trim() || '3000';
    const nets = networkInterfaces();
    for (const addrs of Object.values(nets)) {
      for (const addr of addrs ?? []) {
        const family = String(addr.family);
        if ((family === 'IPv4' || family === '4') && !addr.internal) {
          return `http://${addr.address}:${port}`;
        }
      }
    }
    return undefined;
  }

  private async recipientChatIds(): Promise<string[]> {
    const ids = new Set<string>();
    const envId =
      this.config.get<string>('TELEGRAM_ADMIN_CHAT_ID')?.trim() ||
      this.config.get<string>('TELEGRAM_MANAGERS_CHAT_ID')?.trim();
    if (envId) ids.add(envId);

    try {
      const stored = await this.redis.get(SUBSCRIBERS_KEY);
      if (stored) {
        for (const id of JSON.parse(stored) as string[]) {
          if (id) ids.add(String(id));
        }
      }
    } catch {
      // redis mock / downtime — шлём только на env chat id
    }

    return this.pickAlertChat([...ids]);
  }

  /** One destination: env group, else newest supergroup, else newest group. */
  private pickAlertChat(ids: string[]): string[] {
    const unique = [...new Set(ids.map(String).filter(Boolean))];
    const superGroups = unique.filter((id) => id.startsWith('-100'));
    if (superGroups.length) return [superGroups[superGroups.length - 1]];
    const groups = unique.filter((id) => id.startsWith('-'));
    if (groups.length) return [groups[groups.length - 1]];
    return unique.slice(-1);
  }

  private async rememberChat(chatId: number): Promise<void> {
    const id = String(chatId);
    if (id.startsWith('-')) {
      await this.persistChatIds([id]);
      return;
    }
    const current = await this.recipientChatIds();
    if (current.some((item) => item.startsWith('-'))) return;
    await this.persistChatIds([id]);
  }

  private async replaceChatId(oldId: string, newId: string): Promise<void> {
    const ids = new Set(await this.recipientChatIds());
    ids.delete(oldId);
    ids.add(newId);
    await this.persistChatIds(ids);
  }

  private async persistChatIds(ids: Iterable<string>): Promise<void> {
    try {
      await this.redis.set(SUBSCRIBERS_KEY, JSON.stringify([...ids]));
    } catch {
      this.logger.warn('Не удалось сохранить Telegram chat id в Redis');
    }
  }

  private async pollLoop() {
    while (this.polling) {
      try {
        const data = await this.api<{ ok: boolean; result?: TelegramUpdate[] }>(
          'getUpdates',
          {
            offset: this.offset,
            timeout: 25,
            allowed_updates: ['message', 'my_chat_member'],
          },
        );
        for (const update of data.result ?? []) {
          this.offset = update.update_id + 1;
          await this.handleUpdate(update);
        }
      } catch (error) {
        this.logger.warn(
          `Telegram poll: ${error instanceof Error ? error.message : error}`,
        );
        await new Promise((resolve) => setTimeout(resolve, 3000));
      }
    }
  }

  private async handleUpdate(update: TelegramUpdate) {
    const membership = update.my_chat_member;
    if (membership) {
      const status = membership.new_chat_member.status;
      const isGroup =
        membership.chat.type === 'group' ||
        membership.chat.type === 'supergroup';
      if (isGroup && (status === 'member' || status === 'administrator')) {
        await this.bindChat(membership.chat.id);
      }
      return;
    }

    const message = update.message;
    if (!message?.text) return;

    const text = message.text.trim();
    const isStart =
      text === '/start' ||
      text.startsWith('/start ') ||
      text.startsWith('/start@') ||
      text === '/bind' ||
      text.startsWith('/bind@');

    if (!isStart) return;
    await this.bindChat(message.chat.id);
  }

  private async bindChat(chatId: number) {
    await this.rememberChat(chatId);
    await this.sendMessage(
      String(chatId),
      'Группа привязана. Сюда будет приходить одно сообщение о каждом новом заказе.',
    );
  }

  private formatOrderAlert(alert: TelegramOrderAlert): string {
    const clientLabel = alert.clientName?.trim() || alert.clientPhone;
    const lines = alert.items
      .map(
        (item) =>
          `• ${this.escape(item.name)} × ${item.quantity} — ${item.price.toLocaleString('ru-RU')} ₽`,
      )
      .join('\n');

    return [
      '<b>Новый заказ</b>',
      alert.projectId
        ? `Проект: ${this.escape(alert.projectName ?? '')}`
        : 'Из личной корзины (без проекта)',
      `Клиент: ${this.escape(clientLabel)} (${this.escape(alert.clientPhone)})`,
      `Адрес: ${this.escape(alert.address)}`,
      `Сумма: ${alert.totalAmount.toLocaleString('ru-RU')} ₽`,
      '',
      lines,
    ].join('\n');
  }

  private orderKeyboard(alert: TelegramOrderAlert): UrlButton[][] | undefined {
    const url = this.orderWebUrl(alert.clientId, alert.orderId);
    if (!url) return undefined;
    return [[{ text: 'Открыть заказ', url }]];
  }

  private escape(value: string): string {
    return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  }

  private async sendMessage(
    chatId: string,
    text: string,
    keyboard?: UrlButton[][],
    sent = new Set<string>(),
    retried = false,
  ) {
    if (sent.has(chatId)) return;
    sent.add(chatId);

    const payload: Record<string, unknown> = {
      chat_id: chatId,
      text,
      parse_mode: 'HTML',
      disable_web_page_preview: true,
    };
    if (keyboard) {
      payload.reply_markup = { inline_keyboard: keyboard };
    }

    if (!this.token()) {
      this.logger.log(`[MOCK TELEGRAM] → ${chatId}\n${text}`);
      return;
    }

    try {
      const data = await this.api<TelegramApiResult>('sendMessage', payload);
      if (data.ok) return;

      const migrated = data.parameters?.migrate_to_chat_id;
      if (migrated != null && !retried) {
        const nextId = String(migrated);
        this.logger.warn(
          `Telegram group upgraded ${chatId} → ${nextId}, retrying`,
        );
        await this.replaceChatId(chatId, nextId);
        await this.sendMessage(nextId, text, keyboard, sent, true);
        return;
      }

      if (keyboard && !retried) {
        this.logger.warn(
          `Telegram button rejected (${data.description ?? 'unknown'}), sending without button`,
        );
        sent.delete(chatId);
        await this.sendMessage(chatId, text, undefined, sent, true);
        return;
      }

      this.logger.error(
        `Telegram send failed: ${data.description ?? 'unknown'}`,
      );
    } catch (error) {
      this.logger.error(
        `Telegram send failed: ${error instanceof Error ? error.message : error}`,
      );
    }
  }

  private async api<T>(
    method: string,
    body: Record<string, unknown>,
  ): Promise<T> {
    const token = this.token();
    if (!token) {
      return { ok: false } as T;
    }

    try {
      const response = await fetch(
        `https://api.telegram.org/bot${token}/${method}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        },
      );
      return (await response.json()) as T;
    } catch (error) {
      this.logger.warn(
        `Telegram ${method}: ${error instanceof Error ? error.message : error}`,
      );
      return { ok: false } as T;
    }
  }
}
