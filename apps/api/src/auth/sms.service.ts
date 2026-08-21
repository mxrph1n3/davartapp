import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * OTP delivery.
 * - SMS_PROVIDER=mock (default): log code (dev/test only; fail-closed in production)
 * - SMS_PROVIDER=smsru: SMS.ru (`SMSRU_API_ID` required)
 */
@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);

  constructor(private readonly configService: ConfigService) {}

  async sendOtp(phone: string, code: string): Promise<void> {
    const provider = this.configService.get<string>('SMS_PROVIDER', 'mock');
    const nodeEnv = this.configService.get<string>('NODE_ENV', 'development');

    if (provider === 'mock') {
      if (nodeEnv === 'production') {
        throw new ServiceUnavailableException(
          'SMS provider is not configured for production',
        );
      }
      this.logger.log(`[MOCK SMS] OTP for ${phone}: ${code}`);
      return;
    }

    if (provider === 'smsru') {
      await this.sendViaSmsRu(phone, code);
      return;
    }

    if (nodeEnv === 'production') {
      this.logger.error(
        `SMS provider "${provider}" is not implemented — refusing to send OTP in production`,
      );
      throw new ServiceUnavailableException(
        'SMS provider is not configured for production',
      );
    }

    this.logger.warn(
      `SMS provider "${provider}" is not configured, falling back to mock (non-production only)`,
    );
    this.logger.log(`[MOCK SMS] OTP for ${phone}: ${code}`);
  }

  private async sendViaSmsRu(phone: string, code: string): Promise<void> {
    const apiId = this.configService.get<string>('SMSRU_API_ID');
    if (!apiId) {
      throw new ServiceUnavailableException(
        'SMSRU_API_ID is not configured',
      );
    }

    const message = `Davart: код ${code}`;
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

    this.logger.log(`SMS.ru OTP sent to ${phone}`);
  }
}
