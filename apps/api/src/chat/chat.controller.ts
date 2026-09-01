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
import { UserRole } from '@prisma/client';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { JwtPayload } from '../auth/decorators/current-user.decorator';
import { assertDevEndpointsAllowed } from '../common/dev-endpoints';
import { PushService } from '../push/push.service';
import { ChatGateway } from './chat.gateway';
import { ChatService } from './chat.service';
import {
  AddChatParticipantDto,
  AttachmentUploadUrlDto,
  ChatArchiveQueryDto,
  ChatContactsQueryDto,
  ChatIdParamDto,
  CreatePersonalChatDto,
  InviteChatByPhoneDto,
  MessagesQueryDto,
  ProjectChatParamDto,
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

  @Get('contacts')
  listContacts(
    @CurrentUser() user: JwtPayload,
    @Query() query: ChatContactsQueryDto,
  ) {
    return this.chatService.listContacts(user.sub, query.q);
  }

  @Post('personal')
  createPersonal(
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreatePersonalChatDto,
  ) {
    return this.chatService.getOrCreatePersonalChat(user.sub, dto.userId);
  }

  @Post('invite')
  @HttpCode(200)
  inviteByPhone(
    @CurrentUser() user: JwtPayload,
    @Body() dto: InviteChatByPhoneDto,
  ) {
    return this.chatService.inviteByPhone(user.sub, dto.phone, dto.name);
  }

  @Get('project/:projectId')
  getProjectChat(
    @CurrentUser() user: JwtPayload,
    @Param() params: ProjectChatParamDto,
  ) {
    return this.chatService.openProjectChat(user.sub, params.projectId);
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

  @Post(':id/participants')
  @UseGuards(RolesGuard)
  @Roles(UserRole.complectator, UserRole.admin)
  async addParticipant(
    @CurrentUser() user: JwtPayload,
    @Param() params: ChatIdParamDto,
    @Body() dto: AddChatParticipantDto,
  ) {
    const { chat, message } = await this.chatService.addSupportParticipant(
      user.sub,
      params.id,
      dto.userId,
    );

    if (message) {
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
    }

    return chat;
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
