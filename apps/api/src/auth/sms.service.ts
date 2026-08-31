import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * OTP / invite delivery.
 * - SMS_PROVIDER=mock (default): dev-only, logs code
 * - SMS_PROVIDER=smsru: SMS.ru (`SMSRU_API_ID` required)
 * - SMS_PROVIDER=p1sms: P1SMS (`P1SMS_API_KEY` required), Telegram by default
 */
@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);

  constructor(private readonly configService: ConfigService) {}

  async sendOtp(phone: string, code: string): Promise<void> {
    await this.sendText(phone, `DAVart: код ${code}`);
  }

  async sendText(phone: string, message: string): Promise<void> {
    const provider = this.configService.get<string>('SMS_PROVIDER', 'mock');
    const nodeEnv = this.configService.get<string>('NODE_ENV', 'development');

    if (provider === 'mock') {
      if (nodeEnv === 'production') {
        throw new ServiceUnavailableException(
          'SMS provider is not configured for production',
        );
      }
      this.logger.log(`[MOCK SMS] OTP for ${phone}: ${message}`);
      return;
    }

    if (provider === 'smsru') {
      await this.sendViaSmsRu(phone, message);
      return;
    }

    if (provider === 'p1sms') {
      await this.sendViaP1Sms(phone, message);
      return;
    }

    if (nodeEnv === 'production') {
      this.logger.error(
        `SMS provider "${provider}" is not implemented — refusing to send SMS in production`,
      );
      throw new ServiceUnavailableException(
        'SMS provider is not configured for production',
      );
    }

    this.logger.warn(
      `SMS provider "${provider}" is not configured, falling back to mock (non-production only)`,
    );
    this.logger.log(`[MOCK SMS] OTP for ${phone}: ${message}`);
  }

  private async sendViaP1Sms(phone: string, message: string): Promise<void> {
    const apiKey = this.configService.get<string>('P1SMS_API_KEY');
    if (!apiKey) {
      throw new ServiceUnavailableException('P1SMS_API_KEY is not configured');
    }

    const channel = this.configService.get<string>('P1SMS_CHANNEL', 'telegram');
    const botUsername = this.configService.get<string>('P1SMS_BOT_USERNAME');
    const normalizedPhone = phone.replace(/^\+/, '');

    const smsItem: Record<string, unknown> = {
      channel,
      phone: normalizedPhone,
      text: message,
    };

    if (channel === 'telegram') {
      if (!botUsername) {
        throw new ServiceUnavailableException(
          'P1SMS_BOT_USERNAME is required for Telegram OTP',
        );
      }
      smsItem.tgParameters = [
        {
          botUsername,
          content: [{ baseMessage: true, priority: 1 }],
        },
      ];
    }

    const response = await fetch('https://admin.p1sms.ru/apiSms/create', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        accept: 'application/json',
      },
      body: JSON.stringify({ apiKey, sms: [smsItem] }),
    });

    if (!response.ok) {
      this.logger.error(`P1SMS HTTP ${response.status}`);
      throw new ServiceUnavailableException('Failed to send OTP via P1SMS');
    }

    const body = (await response.json()) as {
      status?: string;
      data?: unknown;
      error?: string;
    };

    if (body.status && body.status !== 'success' && body.status !== 'OK') {
      this.logger.error(`P1SMS error: ${JSON.stringify(body)}`);
      throw new ServiceUnavailableException(
        body.error ?? 'Failed to send OTP via P1SMS',
      );
    }

    this.logger.log(`P1SMS ${channel} sent to ${phone}`);
  }

  private async sendViaSmsRu(phone: string, message: string): Promise<void> {
    const apiId = this.configService.get<string>('SMSRU_API_ID');
    if (!apiId) {
      throw new ServiceUnavailableException(
        'SMSRU_API_ID is not configured',
      );
    }

    const url = new URL('https://sms.ru/sms/send');
    url.searchParams.set('api_id', apiId);
    url.searchParams.set('to', phone.replace(/^\+/, ''));
    url.searchParams.set('msg', message);
    url.searchParams.set('json', '1');

    const response = await fetch(url);
    if (!response.ok) {
      this.logger.error(`SMS.ru HTTP ${response.status}`);
      throw new ServiceUnavailableException('Failed to send SMS');
    }

    const body = (await response.json()) as {
      status?: string;
      status_code?: number;
      status_text?: string;
    };

    if (body.status !== 'OK' && body.status_code !== 100) {
      this.logger.error(`SMS.ru error: ${JSON.stringify(body)}`);
      throw new ServiceUnavailableException(
        body.status_text ?? 'Failed to send SMS',
      );
    }

    this.logger.log(`SMS.ru sent to ${phone}`);
  }
}
