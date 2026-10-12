import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { UserRole } from '@prisma/client';
import { Server, Socket } from 'socket.io';
import type { JwtPayload } from '../auth/decorators/current-user.decorator';
import { hasStudioRole } from '../auth/roles';
import { resolveCorsOrigins } from '../common/env.validation';
import { PrismaService } from '../prisma/prisma.service';
import { ChatService } from './chat.service';

interface AuthedSocket extends Socket {
  data: { user?: JwtPayload };
}

@WebSocketGateway({
  cors: { origin: resolveCorsOrigins(), credentials: true },
  path: '/ws',
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  private readonly logger = new Logger(ChatGateway.name);
  private readonly onlineCounts = new Map<string, number>();

  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly jwtService: JwtService,
    private readonly chatService: ChatService,
    private readonly prisma: PrismaService,
  ) {}

  async handleConnection(client: AuthedSocket) {
    const token = this.extractToken(client);
    if (!token) {
      client.disconnect();
      return;
    }

    try {
      const payload = this.jwtService.verify<{
        sub: string;
        phone?: string;
        role?: UserRole;
      }>(token);

      const user = await this.prisma.user.findUnique({
        where: { id: payload.sub },
        select: { phone: true, role: true, extraRoles: true },
      });
      if (!user) {
        client.disconnect();
        return;
      }

      client.data.user = {
        sub: payload.sub,
        phone: user.phone,
        role: user.role,
        extraRoles: user.extraRoles,
      };
      client.join(`user:${payload.sub}`);
      this.onlineCounts.set(
        payload.sub,
        (this.onlineCounts.get(payload.sub) ?? 0) + 1,
      );
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect(client: AuthedSocket) {
    const userId = client.data.user?.sub;
    if (!userId) return;
    const next = (this.onlineCounts.get(userId) ?? 1) - 1;
    if (next <= 0) this.onlineCounts.delete(userId);
    else this.onlineCounts.set(userId, next);
  }

  isOnline(userId: string) {
    return (this.onlineCounts.get(userId) ?? 0) > 0;
  }

  @SubscribeMessage('join')
  async handleJoin(
    @ConnectedSocket() client: AuthedSocket,
    @MessageBody() chatId: string,
  ) {
    const user = client.data.user;
    if (!user || !chatId) return;

    try {
      await this.chatService.assertParticipant(user.sub, chatId);
      client.join(`chat:${chatId}`);
    } catch (error) {
      this.logger.warn(`Join rejected for chat ${chatId}: ${error}`);
      client.emit('error', { message: 'Access denied' });
    }
  }

  @SubscribeMessage('leave')
  handleLeave(
    @ConnectedSocket() client: AuthedSocket,
    @MessageBody() chatId: string,
  ) {
    if (!chatId) return;
    client.leave(`chat:${chatId}`);
  }

  @SubscribeMessage('typing')
  async handleTyping(
    @ConnectedSocket() client: AuthedSocket,
    @MessageBody() body: { chatId: string; preview?: string },
  ) {
    const user = client.data.user;
    if (!user || !body?.chatId) return;

    try {
      await this.chatService.assertParticipant(user.sub, body.chatId);
    } catch {
      return;
    }

    const roles = [user.role, ...(user.extraRoles ?? [])];
    const previewText =
      !hasStudioRole(roles) && typeof body.preview === 'string'
        ? body.preview.slice(0, 280)
        : '';

    client.to(`chat:${body.chatId}`).emit('typing', {
      chatId: body.chatId,
      userId: user.sub,
      preview: previewText,
    });
  }

  @SubscribeMessage('read')
  async handleRead(
    @ConnectedSocket() client: AuthedSocket,
    @MessageBody() body: { chatId: string },
  ) {
    const user = client.data.user;
    if (!user || !body?.chatId) return;

    try {
      const result = await this.chatService.markRead(user.sub, body.chatId);
      this.server.to(`chat:${body.chatId}`).emit('read', {
        chatId: body.chatId,
        userId: user.sub,
        readAt: result.readAt,
      });
      this.server.to(`user:${user.sub}`).emit('unread:update', {
        total: (await this.chatService.getUnreadTotal(user.sub)).total,
      });
    } catch (error) {
      this.logger.warn(`Read receipt failed: ${error}`);
    }
  }

  emitNewMessage(
    chatId: string,
    message: unknown,
    recipientUserIds: string[] = [],
    options: { skipChatRoom?: boolean } = {},
  ) {
    // Chat-room broadcast is optional so fan-out can send per-viewer payloads
    // without flooding everyone in the thread with the wrong isMine flag.
    if (!options.skipChatRoom) {
      this.server.to(`chat:${chatId}`).emit('message:new', message);
    }
    // Recipients who have not joined the chat room still get the event + list refresh.
    for (const userId of recipientUserIds) {
      this.server.to(`user:${userId}`).emit('message:new', message);
      this.server.to(`user:${userId}`).emit('chats:invalidate', { chatId });
    }
  }

  emitUnreadUpdate(userId: string, total: number) {
    this.server.to(`user:${userId}`).emit('unread:update', { total });
  }

  private extractToken(client: AuthedSocket): string | null {
    const authToken = client.handshake.auth?.token;
    if (typeof authToken === 'string' && authToken.length > 0) {
      return authToken;
    }

    const queryToken = client.handshake.query?.token;
    if (typeof queryToken === 'string' && queryToken.length > 0) {
      return queryToken;
    }

    return null;
  }
}
