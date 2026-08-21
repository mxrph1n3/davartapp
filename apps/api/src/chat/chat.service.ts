import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ChatType, MessageType, Prisma, UserRole } from '@prisma/client';
import { STUDIO_ROLES, canSeeContactPhone, isStudioRole } from '../auth/roles';
import { randomUUID } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import {
  AttachmentUploadUrlDto,
  CHAT_TYPE_LABELS,
  SendMessageDto,
} from './dto/chat.dto';

const DAVART_CHAT_TITLE = 'Davart';

type MessageWithRelations = Prisma.MessageGetPayload<{
  include: {
    sender: { select: { id: true; name: true; phone: true; role: true } };
    product: {
      select: {
        id: true;
        name: true;
        price: true;
        imageUrl: true;
        slug: true;
      };
    };
  };
}>;

@Injectable()
export class ChatService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  async listChats(userId: string) {
    const viewer = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { role: true },
    });

    const participants = await this.prisma.chatParticipant.findMany({
      where: { userId },
      include: {
        chat: {
          include: {
            project: { select: { id: true, name: true, userId: true } },
            participants: {
              include: {
                user: {
                  select: { id: true, name: true, phone: true, role: true },
                },
              },
            },
            messages: {
              orderBy: { createdAt: 'desc' },
              take: 1,
              include: {
                sender: { select: { id: true, name: true, phone: true, role: true } },
              },
            },
          },
        },
      },
      orderBy: { chat: { updatedAt: 'desc' } },
    });

    const items = participants.map((participant) => {
      const lastMessage = participant.chat.messages[0];
      return {
        id: participant.chat.id,
        type: participant.chat.type,
        typeLabel: CHAT_TYPE_LABELS[participant.chat.type],
        title: this.resolveChatTitle(participant.chat, viewer?.role, userId),
        clientId: this.resolveClientId(participant.chat, viewer?.role),
        projectId: participant.chat.projectId,
        unreadCount: participant.unreadCount,
        updatedAt: participant.chat.updatedAt,
        lastMessage: lastMessage
          ? {
              id: lastMessage.id,
              type: lastMessage.type,
              preview: this.messagePreview(lastMessage),
              senderName: this.publicDisplayName(lastMessage.sender),
              createdAt: lastMessage.createdAt,
            }
          : null,
      };
    });

    if (viewer?.role === UserRole.client) {
      items.sort((a, b) => {
        if (a.type === ChatType.support && b.type !== ChatType.support) {
          return -1;
        }
        if (b.type === ChatType.support && a.type !== ChatType.support) {
          return 1;
        }
        return (
          new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime()
        );
      });
    }

    return items;
  }

  async getUnreadTotal(userId: string) {
    const result = await this.prisma.chatParticipant.aggregate({
      where: { userId },
      _sum: { unreadCount: true },
    });

    return { total: result._sum.unreadCount ?? 0 };
  }

  async getOtherParticipantIds(chatId: string, excludeUserId: string) {
    const participants = await this.prisma.chatParticipant.findMany({
      where: { chatId, userId: { not: excludeUserId } },
      select: { userId: true },
    });

    return participants.map((participant) => participant.userId);
  }

  async getMessages(
    userId: string,
    chatId: string,
    page = 1,
    limit = 30,
  ) {
    await this.ensureParticipant(userId, chatId);

    const skip = (page - 1) * limit;
    const [items, total] = await Promise.all([
      this.prisma.message.findMany({
        where: { chatId },
        include: {
          sender: { select: { id: true, name: true, phone: true, role: true } },
          product: {
            select: {
              id: true,
              name: true,
              price: true,
              imageUrl: true,
              slug: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.message.count({ where: { chatId } }),
    ]);

    const formatted = await Promise.all(
      items.map((message) => this.formatMessage(message, userId)),
    );

    return {
      items: formatted.reverse(),
      page,
      limit,
      total,
    };
  }

  async sendMessage(userId: string, chatId: string, dto: SendMessageDto) {
    await this.ensureParticipant(userId, chatId);
    this.validateMessagePayload(dto);

    if (dto.attachmentKey && !dto.attachmentKey.startsWith(`chats/${userId}/attachments/`)) {
      throw new BadRequestException('Attachment key does not belong to sender');
    }

    if (dto.productId) {
      const product = await this.prisma.product.findUnique({
        where: { id: dto.productId },
      });
      if (!product) {
        throw new NotFoundException('Product not found');
      }
    }

    const message = await this.prisma.$transaction(async (tx) => {
      const created = await tx.message.create({
        data: {
          chatId,
          senderId: userId,
          type: dto.type,
          content: dto.content,
          attachmentKey: dto.attachmentKey,
          attachmentName: dto.attachmentName,
          attachmentMime: dto.attachmentMime,
          productId: dto.productId,
        },
        include: {
          sender: { select: { id: true, name: true, phone: true, role: true } },
          product: {
            select: {
              id: true,
              name: true,
              price: true,
              imageUrl: true,
              slug: true,
            },
          },
        },
      });

      await tx.chat.update({
        where: { id: chatId },
        data: { updatedAt: new Date() },
      });

      await tx.chatParticipant.updateMany({
        where: { chatId, userId: { not: userId } },
        data: { unreadCount: { increment: 1 } },
      });

      return created;
    });

    return this.formatMessage(message, userId);
  }

  async getChat(userId: string, chatId: string) {
    await this.ensureParticipant(userId, chatId);

    const chat = await this.prisma.chat.findUnique({
      where: { id: chatId },
      include: {
        project: { select: { id: true, name: true, userId: true } },
        participants: {
          include: {
            user: {
              select: { id: true, name: true, phone: true, role: true },
            },
          },
        },
      },
    });

    if (!chat) {
      throw new NotFoundException('Chat not found');
    }

    const viewer = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { role: true },
    });

    return {
      id: chat.id,
      type: chat.type,
      typeLabel: CHAT_TYPE_LABELS[chat.type],
      title: this.resolveChatTitle(chat, viewer?.role, userId),
      projectId: chat.projectId,
      projectName: chat.project?.name ?? null,
      clientId: this.resolveClientId(chat, viewer?.role),
      participants: chat.participants.map((participant) => ({
        id: participant.user.id,
        name: this.publicDisplayName(participant.user),
        phone: canSeeContactPhone(viewer?.role)
          ? participant.user.phone
          : '',
        role: participant.user.role,
      })),
    };
  }

  async getArchive(
    userId: string,
    chatId: string,
    kind?: 'media' | 'files' | 'voice' | 'links',
  ) {
    await this.ensureParticipant(userId, chatId);

    const messages = await this.prisma.message.findMany({
      where: { chatId },
      include: {
        sender: { select: { id: true, name: true, phone: true, role: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });

    const items: Array<Record<string, unknown>> = [];

    for (const message of messages) {
      if (kind === 'media' && message.type !== MessageType.image) continue;
      if (kind === 'files' && message.type !== MessageType.file) continue;
      if (kind === 'voice' && message.type !== MessageType.voice) continue;

      const urls = this.extractUrls(message.content);
      if (kind === 'links' && urls.length === 0) continue;
      if (!kind) {
        const isArchive =
          message.type === MessageType.image ||
          message.type === MessageType.file ||
          message.type === MessageType.voice ||
          urls.length > 0;
        if (!isArchive) continue;
      }

      let attachmentUrl: string | null = null;
      if (message.attachmentKey && this.storage.isAvailable()) {
        attachmentUrl = await this.storage.getDownloadUrl(message.attachmentKey);
      }

      items.push({
        id: message.id,
        type: message.type,
        content: message.content,
        attachmentUrl,
        attachmentName: message.attachmentName,
        urls,
        senderName: this.publicDisplayName(message.sender),
        createdAt: message.createdAt,
      });
    }

    return { items };
  }

  private extractUrls(content: string | null): string[] {
    if (!content) return [];
    return content.match(/https?:\/\/[^\s<>]+/gi) ?? [];
  }

  async markRead(userId: string, chatId: string) {
    const participant = await this.ensureParticipant(userId, chatId);

    await this.prisma.chatParticipant.update({
      where: { id: participant.id },
      data: { lastReadAt: new Date(), unreadCount: 0 },
    });

    return { chatId, readAt: new Date() };
  }

  async createAttachmentUploadUrl(
    userId: string,
    dto: AttachmentUploadUrlDto,
  ) {
    if (!this.storage.isAvailable()) {
      throw new BadRequestException('File storage is not available');
    }

    if (dto.size != null && dto.size > 50 * 1024 * 1024) {
      throw new BadRequestException('File is too large (max 50 MB)');
    }

    const allowed = [
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/heic',
      'image/heif',
      'image/gif',
      'application/pdf',
      'application/zip',
      'application/x-zip-compressed',
      'application/acad',
      'application/x-dwg',
      'image/vnd.dwg',
      'application/dwg',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'audio/mp4',
      'audio/m4a',
      'audio/aac',
      'audio/mpeg',
      'video/mp4',
    ];
    if (!allowed.includes(dto.contentType.toLowerCase())) {
      throw new BadRequestException('This file type is not allowed');
    }

    const attachmentId = randomUUID();
    const safeName = dto.fileName.replace(/[^a-zA-Z0-9._-]/g, '_');
    const storageKey = `chats/${userId}/attachments/${attachmentId}/${safeName}`;
    const uploadUrl = await this.storage.getUploadUrl(
      storageKey,
      dto.contentType,
    );

    return {
      uploadUrl,
      attachmentKey: storageKey,
      expiresIn: 900,
    };
  }

  /** Remove a demoted user from all Davart support chats (keep their own client chat via ensureDavartChat). */
  async removeStaffFromAllSupportChats(staffId: string) {
    await this.prisma.chatParticipant.deleteMany({
      where: {
        userId: staffId,
        chat: { type: ChatType.support },
      },
    });
  }

  /** Ensures client has a Davart support chat with all staff as participants. */
  async ensureDavartChat(clientId: string) {
    await this.getOrCreateSupportChat(clientId);
  }

  /** Add a staff user to every existing support (Davart) chat. */
  async syncStaffIntoAllSupportChats(staffId: string) {
    const chats = await this.prisma.chat.findMany({
      where: { type: ChatType.support },
      select: { id: true },
    });

    for (const chat of chats) {
      await this.prisma.chatParticipant.upsert({
        where: {
          chatId_userId: { chatId: chat.id, userId: staffId },
        },
        update: {},
        create: { chatId: chat.id, userId: staffId },
      });
    }
  }

  async getOrCreateSupportChat(userId: string) {
    const staffIds = await this.listStaffIds();

    const existing = await this.prisma.chatParticipant.findFirst({
      where: {
        userId,
        chat: { type: ChatType.support },
      },
      include: {
        chat: {
          include: {
            project: { select: { id: true, name: true, userId: true } },
            participants: {
              include: {
                user: {
                  select: { id: true, name: true, phone: true, role: true },
                },
              },
            },
            messages: {
              orderBy: { createdAt: 'desc' },
              take: 1,
              include: {
                sender: { select: { id: true, name: true, phone: true, role: true } },
              },
            },
          },
        },
      },
    });

    if (existing) {
      await this.syncStaffIntoSupportChat(existing.chat.id, staffIds);
      if (existing.chat.title !== DAVART_CHAT_TITLE) {
        await this.prisma.chat.update({
          where: { id: existing.chat.id },
          data: { title: DAVART_CHAT_TITLE },
        });
      }

      const lastMessage = existing.chat.messages[0];
      const viewer = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { role: true },
      });
      return {
        id: existing.chat.id,
        type: existing.chat.type,
        typeLabel: CHAT_TYPE_LABELS[existing.chat.type],
        title: this.resolveChatTitle(
          { ...existing.chat, title: DAVART_CHAT_TITLE },
          viewer?.role,
          userId,
        ),
        projectId: existing.chat.projectId,
        unreadCount: existing.unreadCount,
        updatedAt: existing.chat.updatedAt,
        lastMessage: lastMessage
          ? {
              id: lastMessage.id,
              type: lastMessage.type,
              preview: this.messagePreview(lastMessage),
              senderName: this.publicDisplayName(lastMessage.sender),
              createdAt: lastMessage.createdAt,
            }
          : null,
      };
    }

    const userIds = Array.from(new Set([userId, ...staffIds]));
    const chat = await this.createChatWithParticipants({
      type: ChatType.support,
      title: DAVART_CHAT_TITLE,
      userIds,
    });

    const welcomeSenderId = staffIds[0] ?? userId;
    if (staffIds.length > 0) {
      await this.createSeedMessage({
        chatId: chat.id,
        senderId: welcomeSenderId,
        type: MessageType.text,
        content: 'Здравствуйте! Команда Davart на связи.',
      });
    }

    return {
      id: chat.id,
      type: chat.type,
      typeLabel: CHAT_TYPE_LABELS[chat.type],
      title: DAVART_CHAT_TITLE,
      projectId: null,
      unreadCount: 0,
      updatedAt: chat.updatedAt,
      lastMessage: null,
    };
  }

  async seedDemoChats(userId: string) {
    const existing = await this.prisma.chatParticipant.count({
      where: { userId },
    });
    if (existing > 0) {
      return { message: 'Demo chats already exist' };
    }

    const supportChat = await this.getOrCreateSupportChat(userId);

    const project = await this.prisma.project.findFirst({
      where: { userId },
      orderBy: { createdAt: 'asc' },
    });

    if (project) {
      const designer =
        (project.designerId
          ? await this.prisma.user.findUnique({
              where: { id: project.designerId },
            })
          : null) ??
        (await this.prisma.user.upsert({
          where: { phone: '+79009999999' },
          update: { name: 'Анна Дизайнер', role: UserRole.designer },
          create: {
            phone: '+79009999999',
            name: 'Анна Дизайнер',
            role: UserRole.designer,
          },
        }));

      const projectChat = await this.createChatWithParticipants({
        type: ChatType.project,
        projectId: project.id,
        title: project.name,
        userIds: [userId, designer.id],
      });

      await this.createSeedMessage({
        chatId: projectChat.id,
        senderId: designer.id,
        type: MessageType.text,
        content: `Добрый день! Начинаем работу над проектом «${project.name}».`,
      });
    }

    return { message: 'Demo chats created', supportChatId: supportChat.id };
  }

  private async listStaffIds(): Promise<string[]> {
    const staff = await this.prisma.user.findMany({
      where: { role: { in: STUDIO_ROLES } },
      select: { id: true },
    });
    return staff.map((user) => user.id);
  }

  private async syncStaffIntoSupportChat(
    chatId: string,
    staffIds: string[],
  ): Promise<void> {
    if (staffIds.length === 0) return;

    const existing = await this.prisma.chatParticipant.findMany({
      where: { chatId },
      select: { userId: true },
    });
    const existingIds = new Set(existing.map((row) => row.userId));
    const missing = staffIds.filter((id) => !existingIds.has(id));
    if (missing.length === 0) return;

    await this.prisma.chatParticipant.createMany({
      data: missing.map((userId) => ({ chatId, userId })),
      skipDuplicates: true,
    });
  }

  private async createChatWithParticipants(params: {
    type: ChatType;
    title?: string;
    projectId?: string;
    userIds: string[];
  }) {
    return this.prisma.chat.create({
      data: {
        type: params.type,
        title: params.title,
        projectId: params.projectId,
        participants: {
          create: params.userIds.map((userId) => ({ userId })),
        },
      },
    });
  }

  private async createSeedMessage(params: {
    chatId: string;
    senderId: string;
    type: MessageType;
    content: string;
  }) {
    await this.prisma.$transaction([
      this.prisma.message.create({
        data: {
          chatId: params.chatId,
          senderId: params.senderId,
          type: params.type,
          content: params.content,
        },
      }),
      this.prisma.chat.update({
        where: { id: params.chatId },
        data: { updatedAt: new Date() },
      }),
      this.prisma.chatParticipant.updateMany({
        where: { chatId: params.chatId, userId: { not: params.senderId } },
        data: { unreadCount: { increment: 1 } },
      }),
    ]);
  }

  async assertParticipant(userId: string, chatId: string) {
    return this.ensureParticipant(userId, chatId);
  }

  private async ensureParticipant(userId: string, chatId: string) {
    const participant = await this.prisma.chatParticipant.findUnique({
      where: { chatId_userId: { chatId, userId } },
    });

    if (!participant) {
      throw new ForbiddenException('Access denied');
    }

    return participant;
  }

  private validateMessagePayload(dto: SendMessageDto) {
    if (dto.type === MessageType.text && !dto.content?.trim()) {
      throw new BadRequestException('Text message requires content');
    }

    if (
      (dto.type === MessageType.image ||
        dto.type === MessageType.file ||
        dto.type === MessageType.voice) &&
      !dto.attachmentKey
    ) {
      throw new BadRequestException('Attachment key is required');
    }

    if (dto.attachmentKey) {
      // Must be under chats/{userId}/attachments/ — reject path traversal / other buckets
      const key = dto.attachmentKey;
      if (
        key.includes('..') ||
        !/^chats\/[0-9a-f-]{36}\/attachments\//i.test(key)
      ) {
        throw new BadRequestException('Invalid attachment key');
      }
    }

    if (dto.type === MessageType.product && !dto.productId) {
      throw new BadRequestException('Product id is required');
    }
  }

  private resolveClientId(
    chat: {
      type: ChatType;
      project: { userId: string } | null;
      participants?: Array<{
        user: { id: string; role: UserRole };
      }>;
    },
    viewerRole?: UserRole,
  ): string | null {
    if (!isStudioRole(viewerRole)) return null;
    if (chat.project?.userId) return chat.project.userId;
    if (chat.type === ChatType.support && chat.participants) {
      const client = chat.participants.find(
        (p) => p.user.role === UserRole.client,
      );
      return client?.user.id ?? null;
    }
    return null;
  }

  private resolveChatTitle(
    chat: {
      type: ChatType;
      title: string | null;
      project: { name: string } | null;
      participants?: Array<{
        user: {
          id: string;
          name: string | null;
          phone: string;
          role: UserRole;
        };
      }>;
    },
    viewerRole?: UserRole,
    viewerId?: string,
  ) {
    if (chat.type === ChatType.support) {
      if (isStudioRole(viewerRole) && chat.participants && viewerId) {
        const client = chat.participants.find(
          (p) => p.user.role === UserRole.client && p.user.id !== viewerId,
        );
        if (client) {
          return this.publicDisplayName(client.user, {
            revealPhone: canSeeContactPhone(viewerRole),
          });
        }
      }
      return DAVART_CHAT_TITLE;
    }
    if (chat.title) return chat.title;
    if (chat.project) return chat.project.name;
    return CHAT_TYPE_LABELS[chat.type];
  }

  private publicDisplayName(
    user: {
      name: string | null;
      phone: string;
      role?: UserRole | string;
    },
    options?: { revealPhone?: boolean },
  ) {
    const name = user.name?.trim();
    if (name) return name;
    if (options?.revealPhone) return user.phone;
    if (user.role === UserRole.client || user.role === 'client') {
      return 'Клиент';
    }
    if (user.role) return 'Сотрудник';
    return 'Участник';
  }

  private messagePreview(message: {
    type: MessageType;
    content: string | null;
    attachmentName: string | null;
  }) {
    switch (message.type) {
      case MessageType.text:
        return message.content ?? '';
      case MessageType.image:
        return 'Изображение';
      case MessageType.file:
        return message.attachmentName ?? 'Файл';
      case MessageType.product:
        return 'Товар';
      case MessageType.voice:
        return 'Голосовое';
      default:
        return '';
    }
  }

  buildPushPayload(message: {
    type: string;
    content?: string | null;
    attachmentName?: string | null;
    sender?: { name?: string | null };
  }): { title: string; body: string } {
    const preview = this.messagePreview({
      type: message.type as MessageType,
      content: message.content ?? null,
      attachmentName: message.attachmentName ?? null,
    });
    const senderName = message.sender?.name?.trim();
    return {
      title: senderName && senderName.length > 0 ? senderName : 'Davart',
      body: preview.length > 0 ? preview : 'Новое сообщение',
    };
  }

  private async formatMessage(message: MessageWithRelations, viewerId: string) {
    let attachmentUrl: string | null = null;
    if (message.attachmentKey && this.storage.isAvailable()) {
      attachmentUrl = await this.storage.getDownloadUrl(message.attachmentKey);
    }

    return {
      id: message.id,
      chatId: message.chatId,
      type: message.type,
      content: message.content,
      attachmentUrl,
      attachmentName: message.attachmentName,
      attachmentMime: message.attachmentMime,
      product: message.product
        ? {
            id: message.product.id,
            name: message.product.name,
            price: Number(message.product.price),
            imageUrl: message.product.imageUrl,
            slug: message.product.slug,
          }
        : null,
      sender: {
        id: message.sender.id,
        name: this.publicDisplayName(message.sender),
      },
      isMine: message.senderId === viewerId,
      createdAt: message.createdAt,
    };
  }
}
