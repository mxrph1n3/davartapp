import {
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export type OtpChannel = 'telegram' | 'sms';

/**
 * OTP / invite delivery.
 * - SMS_PROVIDER=mock (default): dev-only, logs code
 * - SMS_PROVIDER=telegram: official Telegram Gateway (`TELEGRAM_GATEWAY_TOKEN`)
 * - SMS_PROVIDER=p1sms: P1SMS Telegram/SMS (`P1SMS_API_KEY`)
 * - SMS_PROVIDER=smsru: SMS.ru (`SMSRU_API_ID`)
 * - SMS_PROVIDER=targetsms: TargetSMS JSON API (`TARGETSMS_LOGIN`, `TARGETSMS_PASSWORD`, `TARGETSMS_SENDER`)
 *
 * SMS fallback (when channel=sms or Telegram fails): SMS_FALLBACK_PROVIDER=smsru|p1sms|targetsms
 */
@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);

  constructor(private readonly configService: ConfigService) {}

  async sendOtp(
    phone: string,
    code: string,
    channel: OtpChannel = 'sms',
  ): Promise<void> {
    const message = `DAVart: код ${code}`;
    // App always requests SMS for login — force SMS path, do not depend on
    // SMS_PROVIDER=telegram (which previously required Gateway token).
    if (channel === 'sms') {
      await this.sendViaSmsFallback(phone, message);
      return;
    }
    await this.sendText(phone, message);
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

    if (provider === 'telegram') {
      // Plain text invites are not supported by Gateway — fall back to SMS.ru/p1sms if set,
      // otherwise log in non-prod.
      const fallback = this.configService.get<string>('SMS_FALLBACK_PROVIDER');
      if (
        fallback === 'smsru' ||
        fallback === 'p1sms' ||
        fallback === 'targetsms'
      ) {
        await this.sendViaSmsFallback(phone, message);
        return;
      }
      if (nodeEnv === 'production') {
        throw new ServiceUnavailableException(
          'Plain SMS invites require SMS_FALLBACK_PROVIDER with telegram OTP',
        );
      }
      this.logger.log(`[MOCK SMS] text for ${phone}: ${message}`);
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

    if (provider === 'targetsms') {
      await this.sendViaTargetSms(phone, message);
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

  /** Explicit SMS channel (OTP fallback button). */
  private async sendViaSmsFallback(
    phone: string,
    message: string,
  ): Promise<void> {
    const rawFallback = this.configService.get<string>('SMS_FALLBACK_PROVIDER');
    const fallback = (
      (rawFallback && rawFallback.trim()) ||
      this.configService.get<string>('SMS_PROVIDER', 'mock') ||
      'mock'
    ).trim();
    const nodeEnv = this.configService.get<string>('NODE_ENV', 'development');

    this.logger.log(`SMS fallback provider: ${fallback}`);

    if (fallback === 'smsru') {
      await this.sendViaSmsRu(phone, message);
      return;
    }

    if (fallback === 'p1sms') {
      await this.sendViaP1Sms(phone, message, 'char');
      return;
    }

    if (fallback === 'targetsms') {
      await this.sendViaTargetSms(phone, message);
      return;
    }

    if (fallback === 'mock' || !fallback) {
      if (nodeEnv === 'production') {
        throw new ServiceUnavailableException(
          'SMS не настроен. Укажите SMS_FALLBACK_PROVIDER=smsru, p1sms или targetsms',
        );
      }
      this.logger.log(`[MOCK SMS] fallback OTP for ${phone}: ${message}`);
      return;
    }

    throw new ServiceUnavailableException(
      `SMS provider "${fallback}" is not available for SMS channel`,
    );
  }

  /**
   * Official Telegram Gateway — delivers OTP into Telegram for the phone number.
   * Token: https://gateway.telegram.org → Access token
   * Custom codes must be 4–8 digits.
   */
  private async sendViaTelegramGateway(
    phone: string,
    code: string,
  ): Promise<void> {
    const token = this.configService.get<string>('TELEGRAM_GATEWAY_TOKEN');
    if (!token) {
      throw new ServiceUnavailableException(
        'TELEGRAM_GATEWAY_TOKEN is not configured',
      );
    }

    const e164 = phone.startsWith('+') ? phone : `+${phone}`;
    const sender = this.configService
      .get<string>('TELEGRAM_GATEWAY_SENDER')
      ?.replace(/^@/, '')
      .trim();

    // Optional free pre-check — if ability check fails, surface a clear error.
    try {
      await this.telegramGatewayRequest(token, 'checkSendAbility', {
        phone_number: e164,
      });
    } catch (error) {
      this.logger.warn(
        `Telegram checkSendAbility failed for ${e164}: ${
          error instanceof Error ? error.message : error
        }`,
      );
      // Still attempt send — ability check is optional / may not be funded.
    }

    const body: Record<string, unknown> = {
      phone_number: e164,
      // Custom code only — do not send code_length (Telegram may ignore `code`
      // and fall back to a default 6-digit generated code when both are set).
      code: String(code),
      ttl: 300,
    };
    if (sender) {
      body.sender_username = sender;
    }

    const result = await this.telegramGatewayRequest(
      token,
      'sendVerificationMessage',
      body,
    );
    this.logger.log(
      `Telegram Gateway OTP sent to ${e164} (custom code length=${String(code).length}) result=${JSON.stringify(result)}`,
    );
  }

  private async telegramGatewayRequest(
    token: string,
    method: string,
    body: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    const response = await fetch(`https://gatewayapi.telegram.org/${method}`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
        accept: 'application/json',
      },
      body: JSON.stringify(body),
    });

    const payload = (await response.json().catch(() => ({}))) as {
      ok?: boolean;
      error?: string;
      result?: Record<string, unknown>;
    };

    if (!response.ok || payload.ok !== true) {
      this.logger.error(
        `Telegram Gateway ${method}: HTTP ${response.status} ${JSON.stringify(payload)}`,
      );
      throw new ServiceUnavailableException(
        payload.error ?? 'Не удалось отправить код в Telegram',
      );
    }

    return payload.result ?? {};
  }

  private async sendViaP1Sms(
    phone: string,
    message: string,
    channelOverride?: string,
  ): Promise<void> {
    const apiKey = this.configService.get<string>('P1SMS_API_KEY');
    if (!apiKey) {
      throw new ServiceUnavailableException('P1SMS_API_KEY is not configured');
    }

    const channel =
      channelOverride ??
      this.configService.get<string>('P1SMS_CHANNEL', 'telegram');
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
      throw new ServiceUnavailableException('SMSRU_API_ID is not configured');
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

  /** TargetSMS JSON API — https://targetsms.ru/images/JSON.pdf */
  private async sendViaTargetSms(
    phone: string,
    message: string,
  ): Promise<void> {
    const login = this.configService.get<string>('TARGETSMS_LOGIN');
    const password = this.configService.get<string>('TARGETSMS_PASSWORD');
    const sender = this.configService.get<string>('TARGETSMS_SENDER');
    if (!login || !password || !sender) {
      throw new ServiceUnavailableException(
        'TARGETSMS_LOGIN, TARGETSMS_PASSWORD and TARGETSMS_SENDER are required',
      );
    }

    const normalizedPhone = phone.replace(/^\+/, '');
    const body = {
      security: { login, password },
      type: 'sms',
      message: [
        {
          type: 'sms',
          sender,
          text: message,
          name_delivery: 'DAVart OTP',
          abonent: [{ phone: normalizedPhone, number_sms: '1' }],
        },
      ],
    };

    let response: Response;
    try {
      response = await fetch('https://sms.targetsms.ru/sendsmsjson.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(8000),
      });
    } catch (error) {
      this.logger.error(
        `TargetSMS network error: ${error instanceof Error ? error.message : error}`,
      );
      throw new ServiceUnavailableException(
        'Не удалось связаться с SMS-провайдером',
      );
    }

    const raw = await response.text();
    if (!response.ok) {
      this.logger.error(
        `TargetSMS HTTP ${response.status}: ${raw.slice(0, 300)}`,
      );
      throw new ServiceUnavailableException('Failed to send SMS via TargetSMS');
    }

    let payload: {
      error?: string;
      sms?: Array<{ action?: string; id_sms?: string | number }>;
    };
    try {
      payload = JSON.parse(raw) as typeof payload;
    } catch {
      this.logger.error(`TargetSMS non-JSON: ${raw.slice(0, 300)}`);
      throw new ServiceUnavailableException(
        'TargetSMS returned invalid response',
      );
    }

    if (payload.error) {
      this.logger.error(`TargetSMS error: ${payload.error}`);
      throw new ServiceUnavailableException(payload.error);
    }

    const first = payload.sms?.[0];
    if (first?.error) {
      this.logger.error(`TargetSMS reject: ${first.error}`);
      throw new ServiceUnavailableException(first.error);
    }
    if (!first?.id_sms || first.action !== 'send') {
      this.logger.error(`TargetSMS reject: ${JSON.stringify(payload)}`);
      throw new ServiceUnavailableException(
        first?.action ?? 'Failed to send SMS via TargetSMS',
      );
    }

    this.logger.log(`TargetSMS sent to ${phone} (id=${first.id_sms})`);
  }
}
