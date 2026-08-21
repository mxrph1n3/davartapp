import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { JwtPayload } from '../auth/decorators/current-user.decorator';
import { assertDevEndpointsAllowed } from '../common/dev-endpoints';
import { PushService } from '../push/push.service';
import { ChatGateway } from './chat.gateway';
import { ChatService } from './chat.service';
import {
  AttachmentUploadUrlDto,
  ChatArchiveQueryDto,
  ChatIdParamDto,
  MessagesQueryDto,
  SendMessageDto,
} from './dto/chat.dto';

@Controller('chats')
@UseGuards(JwtAuthGuard)
export class ChatController {
  constructor(
    private readonly chatService: ChatService,
    private readonly chatGateway: ChatGateway,
    private readonly pushService: PushService,
  ) {}

  @Get()
  list(@CurrentUser() user: JwtPayload) {
    return this.chatService.listChats(user.sub);
  }

  @Get('unread-total')
  unreadTotal(@CurrentUser() user: JwtPayload) {
    return this.chatService.getUnreadTotal(user.sub);
  }

  @Get('support')
  getSupportChat(@CurrentUser() user: JwtPayload) {
    return this.chatService.getOrCreateSupportChat(user.sub);
  }

  @Post('seed-demo')
  @HttpCode(200)
  seedDemo(@CurrentUser() user: JwtPayload) {
    assertDevEndpointsAllowed();
    return this.chatService.seedDemoChats(user.sub);
  }

  @Post('attachments/upload-url')
  createAttachmentUploadUrl(
    @CurrentUser() user: JwtPayload,
    @Body() dto: AttachmentUploadUrlDto,
  ) {
    return this.chatService.createAttachmentUploadUrl(user.sub, dto);
  }

  @Get(':id/archive')
  getArchive(
    @CurrentUser() user: JwtPayload,
    @Param() params: ChatIdParamDto,
    @Query() query: ChatArchiveQueryDto,
  ) {
    return this.chatService.getArchive(user.sub, params.id, query.kind);
  }

  @Get(':id/messages')
  getMessages(
    @CurrentUser() user: JwtPayload,
    @Param() params: ChatIdParamDto,
    @Query() query: MessagesQueryDto,
  ) {
    return this.chatService.getMessages(
      user.sub,
      params.id,
      query.page,
      query.limit,
    );
  }

  @Get(':id')
  getChat(@CurrentUser() user: JwtPayload, @Param() params: ChatIdParamDto) {
    return this.chatService.getChat(user.sub, params.id);
  }

  @Post(':id/messages')
  async sendMessage(
    @CurrentUser() user: JwtPayload,
    @Param() params: ChatIdParamDto,
    @Body() dto: SendMessageDto,
  ) {
    const message = await this.chatService.sendMessage(
      user.sub,
      params.id,
      dto,
    );

    this.chatGateway.emitNewMessage(params.id, message);

    const otherUserIds = await this.chatService.getOtherParticipantIds(
      params.id,
      user.sub,
    );

    for (const userId of otherUserIds) {
      const total = (await this.chatService.getUnreadTotal(userId)).total;
      this.chatGateway.emitUnreadUpdate(userId, total);

      const push = this.chatService.buildPushPayload(message);
      await this.pushService.sendToUser(userId, {
        title: push.title,
        body: push.body,
        data: { type: 'chat', chatId: params.id },
      });
    }

    return message;
  }

  @Post(':id/read')
  @HttpCode(200)
  async markRead(
    @CurrentUser() user: JwtPayload,
    @Param() params: ChatIdParamDto,
  ) {
    const result = await this.chatService.markRead(user.sub, params.id);
    this.chatGateway.server.to(`chat:${params.id}`).emit('read', {
      chatId: params.id,
      userId: user.sub,
      readAt: result.readAt,
    });

    const total = (await this.chatService.getUnreadTotal(user.sub)).total;
    this.chatGateway.emitUnreadUpdate(user.sub, total);

    return result;
  }
}
