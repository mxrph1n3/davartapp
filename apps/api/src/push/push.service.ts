import { createSign } from 'crypto';
import { readFileSync } from 'fs';
import * as http2 from 'http2';

import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export interface PushPayload {
  title: string;
  body: string;
  badge?: number;
  /** Same id replaces a stored notification instead of stacking duplicates. */
  collapseId?: string;
  data?: Record<string, string>;
}

@Injectable()
export class PushService implements OnModuleInit {
  private readonly logger = new Logger(PushService.name);
  private apnsJwtCache?: { token: string; exp: number };
  private apnsKeyCache?: string | null;
  private readonly retryQueue: PendingPush[] = [];
  private retryTimer?: ReturnType<typeof setInterval>;
  private drainingRetries = false;

  constructor(private readonly prisma: PrismaService) {}

  onModuleInit() {
    const key = this.apnsPrivateKey();
    const keyId = process.env.APNS_KEY_ID?.trim();
    if (key && keyId) {
      this.logger.log('APNs key loaded');
      return;
    }
    this.logger.warn(
      'APNs key is not loaded; notifications will not arrive while the app is closed',
    );
  }

  /** True only when a push provider accepted the notification. */
  async sendToUser(userId: string, payload: PushPayload): Promise<boolean> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { notificationsEnabled: true },
    });

    if (!user?.notificationsEnabled) {
      return false;
    }

    const tokens = await this.prisma.fcmToken.findMany({
      where: { userId },
      select: { token: true, platform: true },
    });

    if (tokens.length === 0) {
      this.logger.log(
        `[PUSH] ${userId}: ${payload.title} — ${payload.body} (no tokens)`,
      );
      return false;
    }

    let delivered = false;
    for (const row of tokens) {
      if (await this.sendToToken(row.token, row.platform, payload)) {
        delivered = true;
      }
    }
    return delivered;
  }

  private async sendToToken(
    token: string,
    platform: string | null,
    payload: PushPayload,
  ): Promise<boolean> {
    if (this.isApnsToken(token, platform)) {
      const delivered = await this.sendApns(token, platform, payload);
      if (
        !delivered &&
        this.apnsPrivateKey() &&
        process.env.APNS_KEY_ID?.trim()
      ) {
        this.enqueueRetry(token, platform, payload);
      }
      return delivered;
    }

    if (token.startsWith('davart-')) {
      this.logger.warn(
        `[PUSH] ${token.slice(0, 16)}… is not a device token, notification was not sent`,
      );
      return false;
    }

    const serverKey = process.env.FCM_SERVER_KEY;

    if (!serverKey) {
      this.logger.log(
        `[PUSH MOCK] ${token.slice(0, 12)}...: ${payload.title} — ${payload.body}`,
      );
      return false;
    }

    try {
      const response = await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          Authorization: `key=${serverKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          to: token,
          notification: {
            title: payload.title,
            body: payload.body,
          },
          data: payload.data ?? {},
        }),
      });
      return response.ok;
    } catch (error) {
      this.logger.warn(`FCM send failed: ${error}`);
      return false;
    }
  }

  private isApnsToken(token: string, platform: string | null) {
    if (platform !== 'ios' && platform !== 'ios-sandbox') return false;
    return /^[0-9a-f]{64,}$/i.test(token);
  }

  private apnsPrivateKey() {
    if (this.apnsKeyCache !== undefined) return this.apnsKeyCache;
    const inline = process.env.APNS_PRIVATE_KEY?.trim();
    if (inline) {
      this.apnsKeyCache = inline.replace(/\\n/g, '\n');
      return this.apnsKeyCache;
    }
    const path = process.env.APNS_KEY_PATH?.trim();
    if (!path) {
      this.apnsKeyCache = null;
      return null;
    }
    try {
      this.apnsKeyCache = readFileSync(path, 'utf8');
    } catch (error) {
      this.logger.warn(`APNs key file unreadable: ${error}`);
      this.apnsKeyCache = null;
    }
    return this.apnsKeyCache;
  }

  private apnsJwt(key: string, keyId: string, teamId: string) {
    const now = Math.floor(Date.now() / 1000);
    if (this.apnsJwtCache && this.apnsJwtCache.exp > now + 60) {
      return this.apnsJwtCache.token;
    }
    const header = Buffer.from(
      JSON.stringify({ alg: 'ES256', kid: keyId }),
    ).toString('base64url');
    const claims = Buffer.from(
      JSON.stringify({ iss: teamId, iat: now }),
    ).toString('base64url');
    const unsigned = `${header}.${claims}`;
    const signer = createSign('SHA256');
    signer.update(unsigned);
    const signature = signer.sign({ key, dsaEncoding: 'ieee-p1363' });
    const token = `${unsigned}.${Buffer.from(signature).toString('base64url')}`;
    this.apnsJwtCache = { token, exp: now + 50 * 60 };
    return token;
  }

  private async sendApns(
    token: string,
    platform: string | null,
    payload: PushPayload,
  ): Promise<boolean> {
    const key = this.apnsPrivateKey();
    const keyId = process.env.APNS_KEY_ID?.trim();
    const teamId = process.env.APNS_TEAM_ID?.trim();
    const topic = process.env.APNS_BUNDLE_ID?.trim() || 'com.davart.app';

    if (!key || !keyId || !teamId) {
      this.logger.log(
        `[PUSH] iOS ${payload.title} — ${payload.body} (нет APNS_KEY_ID / APNS_TEAM_ID / ключа .p8)`,
      );
      return false;
    }

    const jwt = this.apnsJwt(key, keyId, teamId);
    const body = JSON.stringify({
      aps: {
        alert: { title: payload.title, body: payload.body },
        sound: 'default',
        ...(payload.badge != null ? { badge: payload.badge } : {}),
      },
      ...(payload.data ?? {}),
    });
    const hosts =
      platform === 'ios-sandbox'
        ? ['api.sandbox.push.apple.com', 'api.push.apple.com']
        : ['api.push.apple.com', 'api.sandbox.push.apple.com'];

    let sawDeadToken = false;
    for (const host of hosts) {
      const result = await this.postApns(
        host,
        token,
        topic,
        jwt,
        body,
        payload.collapseId,
      );
      if (result.ok) {
        const nextPlatform = host.includes('sandbox') ? 'ios-sandbox' : 'ios';
        if (nextPlatform !== platform) {
          await this.prisma.fcmToken.updateMany({
            where: { token },
            data: { platform: nextPlatform },
          });
        }
        return true;
      }
      if (result.deadToken) sawDeadToken = true;
      if (!result.deadToken && !result.retryable) break;
    }

    if (sawDeadToken) {
      await this.prisma.fcmToken.deleteMany({ where: { token } });
    }
    return false;
  }

  /**
   * Apple keeps the alert until this moment, including while the phone is off.
   * A later retry with the same collapse id replaces that stored alert.
   */
  private apnsExpiration() {
    return String(Math.floor(Date.now() / 1000) + 30 * 24 * 60 * 60);
  }

  private postApns(
    host: string,
    token: string,
    topic: string,
    jwt: string,
    body: string,
    collapseId?: string,
  ): Promise<{ ok: boolean; deadToken: boolean; retryable: boolean }> {
    return new Promise((resolve) => {
      const client = http2.connect(`https://${host}`);
      let settled = false;
      // Assigned below, after finish() that clears it is defined.
      // eslint-disable-next-line prefer-const
      let timer: ReturnType<typeof setTimeout>;
      const finish = (value: {
        ok: boolean;
        deadToken: boolean;
        retryable: boolean;
      }) => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        client.close();
        resolve(value);
      };
      timer = setTimeout(() => {
        this.logger.warn(
          `APNs timed out for ${token.slice(0, 8)}… via ${host}`,
        );
        finish({ ok: false, deadToken: false, retryable: true });
      }, 12_000);
      client.on('error', (error) => {
        this.logger.warn(`APNs connection failed (${host}): ${error}`);
        finish({ ok: false, deadToken: false, retryable: true });
      });
      const req = client.request({
        ':method': 'POST',
        ':path': `/3/device/${token}`,
        ':authority': host,
        authorization: `bearer ${jwt}`,
        'apns-topic': topic,
        'apns-push-type': 'alert',
        'apns-priority': '10',
        'apns-expiration': this.apnsExpiration(),
        ...(collapseId ? { 'apns-collapse-id': collapseId.slice(0, 64) } : {}),
      });
      let status = 0;
      let response = '';
      req.setEncoding('utf8');
      req.on('response', (headers) => {
        status = Number(headers[':status'] ?? 0);
      });
      req.on('data', (chunk) => {
        response += chunk;
      });
      req.on('end', () => {
        if (status === 200) {
          finish({ ok: true, deadToken: false, retryable: false });
          return;
        }
        this.logger.warn(
          `APNs ${status} for ${token.slice(0, 8)}… via ${host}: ${response}`,
        );
        const deadToken =
          status === 410 ||
          response.includes('Unregistered') ||
          response.includes('BadDeviceToken');
        const retryable = status === 429 || status >= 500 || status === 0;
        finish({ ok: false, deadToken, retryable });
      });
      req.on('error', (error) => {
        this.logger.warn(`APNs request failed (${host}): ${error}`);
        finish({ ok: false, deadToken: false, retryable: true });
      });
      req.end(body);
    });
  }

  private enqueueRetry(
    token: string,
    platform: string | null,
    payload: PushPayload,
  ) {
    if (this.retryQueue.length >= 200) this.retryQueue.shift();
    this.retryQueue.push({
      token,
      platform,
      payload,
      attempt: 1,
      notBefore: Date.now() + 30_000,
    });
    if (this.retryTimer) return;
    this.retryTimer = setInterval(() => {
      void this.drainRetries();
    }, 15_000);
    this.retryTimer.unref?.();
  }

  private async drainRetries() {
    if (this.drainingRetries) return;
    this.drainingRetries = true;
    try {
      const now = Date.now();
      const due = this.retryQueue.filter((item) => item.notBefore <= now);
      for (const item of due) {
        const index = this.retryQueue.indexOf(item);
        if (index >= 0) this.retryQueue.splice(index, 1);
        const delivered = await this.sendApns(
          item.token,
          item.platform,
          item.payload,
        );
        if (delivered || item.attempt >= 6) continue;
        item.attempt += 1;
        item.notBefore =
          now + Math.min(30 * 60_000, 30_000 * 2 ** item.attempt);
        this.retryQueue.push(item);
      }
      if (this.retryQueue.length === 0 && this.retryTimer) {
        clearInterval(this.retryTimer);
        this.retryTimer = undefined;
      }
    } finally {
      this.drainingRetries = false;
    }
  }
}

interface PendingPush {
  token: string;
  platform: string | null;
  payload: PushPayload;
  attempt: number;
  notBefore: number;
}
