import { createSign } from 'crypto';
import { readFileSync } from 'fs';
import * as http2 from 'http2';

import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export interface PushPayload {
  title: string;
  body: string;
  badge?: number;
  data?: Record<string, string>;
}

@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);
  private apnsJwtCache?: { token: string; exp: number };
  private apnsKeyCache?: string | null;

  constructor(private readonly prisma: PrismaService) {}

  async sendToUser(userId: string, payload: PushPayload) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { notificationsEnabled: true },
    });

    if (!user?.notificationsEnabled) {
      return;
    }

    const tokens = await this.prisma.fcmToken.findMany({
      where: { userId },
      select: { token: true, platform: true },
    });

    if (tokens.length === 0) {
      this.logger.log(
        `[PUSH] ${userId}: ${payload.title} — ${payload.body} (no tokens)`,
      );
      return;
    }

    for (const row of tokens) {
      await this.sendToToken(row.token, row.platform, payload);
    }
  }

  private async sendToToken(
    token: string,
    platform: string | null,
    payload: PushPayload,
  ) {
    if (this.isApnsToken(token, platform)) {
      await this.sendApns(token, platform, payload);
      return;
    }

    const serverKey = process.env.FCM_SERVER_KEY;

    if (!serverKey) {
      this.logger.log(
        `[PUSH MOCK] ${token.slice(0, 12)}...: ${payload.title} — ${payload.body}`,
      );
      return;
    }

    try {
      await fetch('https://fcm.googleapis.com/fcm/send', {
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
    } catch (error) {
      this.logger.warn(`FCM send failed: ${error}`);
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
  ) {
    const key = this.apnsPrivateKey();
    const keyId = process.env.APNS_KEY_ID?.trim();
    const teamId = process.env.APNS_TEAM_ID?.trim();
    const topic = process.env.APNS_BUNDLE_ID?.trim() || 'com.davart.app';

    if (!key || !keyId || !teamId) {
      this.logger.log(
        `[PUSH] iOS ${payload.title} — ${payload.body} (нет APNS_KEY_ID / APNS_TEAM_ID / ключа .p8)`,
      );
      return;
    }

    const sandbox = platform === 'ios-sandbox';
    const host = sandbox
      ? 'api.sandbox.push.apple.com'
      : 'api.push.apple.com';
    const jwt = this.apnsJwt(key, keyId, teamId);
    const body = JSON.stringify({
      aps: {
        alert: { title: payload.title, body: payload.body },
        sound: 'default',
        ...(payload.badge != null ? { badge: payload.badge } : {}),
      },
      ...(payload.data ?? {}),
    });

    await new Promise<void>((resolve) => {
      const client = http2.connect(`https://${host}`);
    let settled = false;
    const finish = () => {
      if (settled) return;
      settled = true;
      client.close();
      resolve();
    };
      client.on('error', (error) => {
        this.logger.warn(`APNs connection failed: ${error}`);
        finish();
      });
      const req = client.request({
        ':method': 'POST',
        ':path': `/3/device/${token}`,
        authorization: `bearer ${jwt}`,
        'apns-topic': topic,
        'apns-push-type': 'alert',
        'apns-priority': '10',
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
        if (status !== 200) {
          this.logger.warn(`APNs ${status} for ${token.slice(0, 8)}…: ${response}`);
          if (
            status === 410 ||
            response.includes('Unregistered') ||
            response.includes('BadDeviceToken')
          ) {
            void this.prisma.fcmToken.deleteMany({ where: { token } });
          }
        }
        finish();
      });
      req.on('error', (error) => {
        this.logger.warn(`APNs request failed: ${error}`);
        finish();
      });
      req.end(body);
    });
  }
}
