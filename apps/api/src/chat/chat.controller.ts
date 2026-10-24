import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { UserRole } from '@prisma/client';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { JwtPayload } from '../auth/decorators/current-user.decorator';
import { assertDevEndpointsAllowed } from '../common/dev-endpoints';
import { ChatDeliveryService } from './chat-delivery.service';
import { ChatGateway } from './chat.gateway';
import { ChatService } from './chat.service';
import {
  AddChatParticipantDto,
  AttachmentUploadUrlDto,
  ChatArchiveQueryDto,
  ChatContactsQueryDto,
  ChatIdParamDto,
  CreateGroupChatDto,
  CreatePersonalChatDto,
  ForwardMessageDto,
  InviteChatByPhoneDto,
  MatchPhonesDto,
  MessageIdParamDto,
  MessagesQueryDto,
  ProjectChatParamDto,
  SendMessageDto,
  SetChatMutedDto,
  SetChatPinnedDto,
  ToggleReactionDto,
  UpdateChatDto,
} from './dto/chat.dto';

@Controller('chats')
@UseGuards(JwtAuthGuard)
export class ChatController {
  constructor(
    private readonly chatService: ChatService,
    private readonly chatGateway: ChatGateway,
    private readonly delivery: ChatDeliveryService,
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

  @Post('group')
  createGroup(
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateGroupChatDto,
  ) {
    return this.chatService.createGroup(user.sub, dto.title, dto.userIds);
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

  @Post('match-phones')
  @HttpCode(200)
  matchPhones(@CurrentUser() user: JwtPayload, @Body() dto: MatchPhonesDto) {
    return this.chatService.matchPhones(user.sub, dto.phones ?? []);
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

  @Post('attachments/upload')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: memoryStorage(),
      limits: { fileSize: 50 * 1024 * 1024 },
    }),
  )
  uploadAttachment(
    @CurrentUser() user: JwtPayload,
    @UploadedFile()
    file:
      | {
          originalname: string;
          mimetype: string;
          size: number;
          buffer: Buffer;
        }
      | undefined,
  ) {
    if (!file) {
      throw new BadRequestException('File is required');
    }
    return this.chatService.uploadAttachment(user.sub, file);
  }

  @Get(':id/pinned')
  getPinned(@CurrentUser() user: JwtPayload, @Param() params: ChatIdParamDto) {
    return this.chatService.getPinnedMessage(user.sub, params.id);
  }

  @Post(':id/messages/:messageId/reactions')
  @HttpCode(200)
  async toggleReaction(
    @CurrentUser() user: JwtPayload,
    @Param() params: MessageIdParamDto,
    @Body() dto: ToggleReactionDto,
  ) {
    const message = await this.chatService.toggleReaction(
      user.sub,
      params.id,
      params.messageId,
      dto.emoji,
    );
    const otherUserIds = await this.chatService.getOtherParticipantIds(
      params.id,
      user.sub,
    );
    this.chatGateway.emitNewMessage(params.id, message, [
      ...otherUserIds,
      user.sub,
    ]);
    return message;
  }

  @Post(':id/messages/:messageId/pin')
  @HttpCode(200)
  async pinMessage(
    @CurrentUser() user: JwtPayload,
    @Param() params: MessageIdParamDto,
  ) {
    const message = await this.chatService.setPinned(
      user.sub,
      params.id,
      params.messageId,
      true,
    );
    const otherUserIds = await this.chatService.getOtherParticipantIds(
      params.id,
      user.sub,
    );
    this.chatGateway.emitNewMessage(params.id, message, [
      ...otherUserIds,
      user.sub,
    ]);
    return message;
  }

  @Post(':id/messages/:messageId/unpin')
  @HttpCode(200)
  async unpinMessage(
    @CurrentUser() user: JwtPayload,
    @Param() params: MessageIdParamDto,
  ) {
    const message = await this.chatService.setPinned(
      user.sub,
      params.id,
      params.messageId,
      false,
    );
    const otherUserIds = await this.chatService.getOtherParticipantIds(
      params.id,
      user.sub,
    );
    this.chatGateway.emitNewMessage(params.id, message, [
      ...otherUserIds,
      user.sub,
    ]);
    return message;
  }

  @Post(':id/messages/:messageId/forward')
  async forwardMessage(
    @CurrentUser() user: JwtPayload,
    @Param() params: MessageIdParamDto,
    @Body() dto: ForwardMessageDto,
  ) {
    const message = await this.chatService.forwardMessage(
      user.sub,
      params.id,
      params.messageId,
      dto.targetChatId,
    );
    await this.publishLive(user.sub, dto.targetChatId, message);
    return message;
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

  @Patch(':id')
  updateChat(
    @CurrentUser() user: JwtPayload,
    @Param() params: ChatIdParamDto,
    @Body() dto: UpdateChatDto,
  ) {
    return this.chatService.updateChat(user.sub, params.id, {
      title: dto.title,
      alias: dto.alias,
    });
  }

  @Patch(':id/pin')
  setPinned(
    @CurrentUser() user: JwtPayload,
    @Param() params: ChatIdParamDto,
    @Body() dto: SetChatPinnedDto,
  ) {
    return this.chatService.setChatPinned(user.sub, params.id, dto.pinned);
  }

  @Patch(':id/mute')
  setMuted(
    @CurrentUser() user: JwtPayload,
    @Param() params: ChatIdParamDto,
    @Body() dto: SetChatMutedDto,
  ) {
    return this.chatService.setMuted(user.sub, params.id, dto.muted);
  }

  @Post(':id/leave')
  @HttpCode(200)
  leaveGroup(@CurrentUser() user: JwtPayload, @Param() params: ChatIdParamDto) {
    return this.chatService.leaveGroup(user.sub, params.id);
  }

  @Delete(':id')
  @HttpCode(200)
  dismissChat(
    @CurrentUser() user: JwtPayload,
    @Param() params: ChatIdParamDto,
  ) {
    return this.chatService.dismissChat(user.sub, params.id);
  }

  @Post(':id/members')
  @HttpCode(200)
  addGroupMembers(
    @CurrentUser() user: JwtPayload,
    @Param() params: ChatIdParamDto,
    @Body() body: { userIds?: string[] },
  ) {
    return this.chatService.addGroupMembers(
      user.sub,
      params.id,
      body.userIds ?? [],
    );
  }

  @Delete(':id/members/:userId')
  @HttpCode(200)
  removeGroupMember(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) chatId: string,
    @Param('userId', ParseUUIDPipe) userId: string,
  ) {
    return this.chatService.removeGroupMember(user.sub, chatId, userId);
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
      const otherUserIds = await this.chatService.getOtherParticipantIds(
        params.id,
        user.sub,
      );
      this.chatGateway.emitNewMessage(params.id, message, [
        ...otherUserIds,
        user.sub,
      ]);

      for (const userId of otherUserIds) {
        this.delivery.scheduleDelivery(userId, params.id, message);
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

    await this.publishLive(user.sub, params.id, message);
    return message;
  }

  private publishLive(
    actorId: string,
    chatId: string,
    message: Parameters<ChatDeliveryService['publishLive']>[2],
  ) {
    return this.delivery.publishLive(actorId, chatId, message);
  }

  @Post(':id/read')
  @HttpCode(200)
  async markRead(
    @CurrentUser() user: JwtPayload,
    @Param() params: ChatIdParamDto,
  ) {
    const result = await this.chatService.markRead(user.sub, params.id);
    this.chatGateway.publishReadReceipts(result.receipts);

    const total = (await this.chatService.getUnreadTotal(user.sub)).total;
    this.chatGateway.emitUnreadUpdate(user.sub, total);

    return result;
  }
}
