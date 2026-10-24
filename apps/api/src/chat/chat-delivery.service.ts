import { Injectable, Logger } from '@nestjs/common';
import { PushService } from '../push/push.service';
import { ChatGateway } from './chat.gateway';
import { ChatService } from './chat.service';

type DeliveredMessage = {
  id?: string;
  chatId: string;
  type: string;
  content?: string | null;
  attachmentName?: string | null;
  sender?: { id: string; name?: string | null };
  isMine?: boolean;
};

/**
 * Live delivery of a stored message: socket copies for every viewer, then push.
 * Shared by the chat controller and server-side senders (order alerts).
 */
@Injectable()
export class ChatDeliveryService {
  private readonly logger = new Logger(ChatDeliveryService.name);

  constructor(
    private readonly chatService: ChatService,
    private readonly chatGateway: ChatGateway,
    private readonly pushService: PushService,
  ) {}

  /**
   * Each phone may have a different chat id for the same person.
   * Send a correctly labeled copy to every such id, then return.
   * Push runs after the HTTP response. Chat text is never sent by SMS.
   */
  async publishLive(
    actorId: string,
    chatId: string,
    message: DeliveredMessage,
  ) {
    const others = await this.chatService.getOtherParticipantIds(
      chatId,
      actorId,
    );
    const viewers = [...new Set([actorId, ...others])];

    for (const viewerId of viewers) {
      const labeled = this.chatService.asViewerMessage(message, viewerId);
      const threadIds = await this.chatService.listDeliveryChatIds(
        viewerId,
        chatId,
      );
      for (const threadId of threadIds) {
        this.chatGateway.emitNewMessage(
          threadId,
          { ...labeled, chatId: threadId },
          [viewerId],
          { skipChatRoom: true },
        );
      }
    }

    for (const recipientId of others) {
      this.scheduleDelivery(recipientId, chatId, message);
    }
  }

  /** Push must not hold the HTTP response. The sender's app times out at 10s. */
  scheduleDelivery(userId: string, chatId: string, message: DeliveredMessage) {
    void this.deliverToRecipient(userId, chatId, message).catch((error) => {
      this.logger.warn(`Chat delivery failed for ${userId}: ${error}`);
    });
  }

  /** Socket if the app is open. Apple stores the same alert for a closed or powered-off phone. Never SMS. */
  private async deliverToRecipient(
    userId: string,
    chatId: string,
    message: DeliveredMessage,
  ) {
    const total = (await this.chatService.getUnreadTotal(userId)).total;
    this.chatGateway.emitUnreadUpdate(userId, total);
    if (await this.chatService.isChatMuted(userId, chatId)) return;
    const push = this.chatService.buildPushPayload(message);
    const destination = await this.chatService.preferredChatId(userId, chatId);
    await this.pushService.sendToUser(userId, {
      title: push.title,
      body: push.body,
      badge: total,
      collapseId: message.id,
      data: { type: 'chat', chatId: destination, title: push.title },
    });
  }
}
