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
import { Server, Socket } from 'socket.io';
import type { JwtPayload } from '../auth/decorators/current-user.decorator';
import { resolveCorsOrigins } from '../common/env.validation';
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

  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly jwtService: JwtService,
    private readonly chatService: ChatService,
  ) {}

  handleConnection(client: AuthedSocket) {
    const token = this.extractToken(client);
    if (!token) {
      client.disconnect();
      return;
    }

    try {
      const payload = this.jwtService.verify<JwtPayload>(token);
      client.data.user = payload;
      client.join(`user:${payload.sub}`);
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect(_client: AuthedSocket) {
    // no-op
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
    @MessageBody() body: { chatId: string },
  ) {
    const user = client.data.user;
    if (!user || !body?.chatId) return;

    try {
      await this.chatService.assertParticipant(user.sub, body.chatId);
    } catch {
      return;
    }

    client.to(`chat:${body.chatId}`).emit('typing', {
      chatId: body.chatId,
      userId: user.sub,
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

  emitNewMessage(chatId: string, message: unknown) {
    this.server.to(`chat:${chatId}`).emit('message:new', message);
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
