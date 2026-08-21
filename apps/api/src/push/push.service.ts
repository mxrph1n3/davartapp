import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export interface PushPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);

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
      select: { token: true },
    });

    if (tokens.length === 0) {
      this.logger.log(
        `[PUSH] ${userId}: ${payload.title} — ${payload.body} (no tokens)`,
      );
      return;
    }

    for (const { token } of tokens) {
      await this.sendToToken(token, payload);
    }
  }

  private async sendToToken(token: string, payload: PushPayload) {
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
}
