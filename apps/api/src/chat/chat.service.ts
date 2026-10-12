import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ChatType, MessageType, Prisma, UserRole } from '@prisma/client';
import {
  canSeeContactPhone,
  hasSupportDutyRole,
  hasStudioRole,
  isStudioRole,
  allRolesOf,
  SUPPORT_DUTY_ROLES,
} from '../auth/roles';
import { SmsService } from '../auth/sms.service';
import { actorProjectAccessWhere } from '../projects/project-access';
import { randomUUID } from 'crypto';
import { resolveProductImageUrl } from '../catalog/demo-product-image';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';
import { StorageService } from '../storage/storage.service';
import { PushService } from '../push/push.service';
import {
  AttachmentUploadUrlDto,
  CHAT_TYPE_LABELS,
  SendMessageDto,
} from './dto/chat.dto';

const DAVART_CHAT_TITLE = 'DAVart';
const SUPPORT_ROSTER_REDIS_PREFIX = 'chat:support-roster:v3:';

const PROJECT_WELCOME_MESSAGE = [
  'Добро пожаловать в чат DAVart дизайн 😌',
  '',
  'Вопросы по проекту вы можете оставлять в чате.',
  '',
  'Также вы можете нам позвонить +74994445028 или написать',
  'info@davart.ru.',
  'Наш сайт davart.ru',
  '',
  'Договор на разработку проектов http://davart.ru/oferta',
].join('\n');

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
    replyTo: {
      select: {
        id: true;
        type: true;
        content: true;
        attachmentName: true;
        sender: { select: { id: true; name: true; phone: true; role: true } };
      };
    };
    reactions: {
      select: { emoji: true; userId: true };
    };
  };
}>;

const messageInclude = {
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
  replyTo: {
    select: {
      id: true,
      type: true,
      content: true,
      attachmentName: true,
      sender: { select: { id: true, name: true, phone: true, role: true } },
    },
  },
  reactions: {
    select: { emoji: true, userId: true },
  },
} as const;

@Injectable()
export class ChatService {
  private readonly logger = new Logger(ChatService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    private readonly redis: RedisService,
    private readonly pushService: PushService,
    private readonly smsService: SmsService,
    private readonly configService: ConfigService,
  ) {}

  async listChats(userId: string) {
    const viewer = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { role: true, extraRoles: true },
    });
    const viewerRoles = viewer ? [viewer.role, ...viewer.extraRoles] : [];
    const viewerRole =
      viewerRoles.find((role) => isStudioRole(role)) ?? viewer?.role;

    const participants = await this.prisma.chatParticipant.findMany({
      where: { userId, hiddenAt: null },
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
                sender: {
                  select: { id: true, name: true, phone: true, role: true },
                },
              },
            },
          },
        },
      },
      orderBy: { chat: { updatedAt: 'desc' } },
    });

    const buckets = new Map<string, typeof participants>();
    for (const participant of participants) {
      const key = this.personalPeerKey(participant.chat, userId);
      const bucket = buckets.get(key) ?? [];
      bucket.push(participant);
      buckets.set(key, bucket);
    }

    const items = [...buckets.values()].map((bucket) => {
      const participant = bucket.reduce((best, row) => {
        const bestAt =
          best.chat.messages[0]?.createdAt ?? best.chat.updatedAt;
        const rowAt = row.chat.messages[0]?.createdAt ?? row.chat.updatedAt;
        return rowAt > bestAt ? row : best;
      });
      const lastMessage = bucket
        .map((row) => row.chat.messages[0])
        .filter((message) => message != null)
        .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())[0];
      return {
        id: participant.chat.id,
        type: participant.chat.type,
        typeLabel: CHAT_TYPE_LABELS[participant.chat.type],
        title: this.resolveChatTitle(participant.chat, viewerRole, userId),
        clientId: this.resolveClientId(participant.chat, viewerRole),
        projectId: participant.chat.projectId,
        unreadCount: bucket.reduce((sum, row) => sum + row.unreadCount, 0),
        updatedAt: lastMessage?.createdAt ?? participant.chat.updatedAt,
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

    if (viewerRole === UserRole.client) {
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
      where: { userId, hiddenAt: null },
      _sum: { unreadCount: true },
    });

    return { total: result._sum.unreadCount ?? 0 };
  }

  async listContacts(userId: string, q?: string) {
    const viewer = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true },
    });
    if (!viewer) throw new NotFoundException('User not found');

    const query = q?.trim();

    const namePhoneFilter: Prisma.UserWhereInput | undefined = query
      ? {
          OR: [
            { name: { contains: query, mode: 'insensitive' } },
            { phone: { contains: query } },
          ],
        }
      : undefined;

    const users = await this.prisma.user.findMany({
      where: {
        id: { not: userId },
        ...(namePhoneFilter ?? {}),
      },
      select: { id: true, name: true, phone: true, role: true },
      orderBy: [{ name: 'asc' }, { phone: 'asc' }],
      take: query ? 200 : 2000,
    });

    const seen = new Set<string>();
    return {
      items: users
        .filter((user) => {
          if (user.id === userId || seen.has(user.id)) return false;
          seen.add(user.id);
          return true;
        })
        .map((user) => ({
          id: user.id,
          name: this.publicDisplayName(user, {
            // Clients need phone/name to recognize people they message.
            revealPhone: true,
          }),
          // Phone is required for invite/search UX for everyone in contacts.
          phone: user.phone,
          role: user.role,
          roleLabel: this.contactRoleLabel(user.role),
        })),
    };
  }

  async getOrCreatePersonalChat(userId: string, otherUserId: string) {
    if (userId === otherUserId) {
      throw new BadRequestException('Cannot chat with yourself');
    }

    const other = await this.prisma.user.findUnique({
      where: { id: otherUserId },
      select: { id: true, name: true, phone: true, role: true },
    });
    if (!other) throw new NotFoundException('User not found');

    const candidates = await this.prisma.chat.findMany({
      where: {
        type: ChatType.personal,
        AND: [
          { participants: { some: { userId } } },
          { participants: { some: { userId: otherUserId } } },
        ],
      },
      include: {
        participants: { select: { userId: true } },
        project: { select: { id: true, name: true, userId: true } },
      },
      orderBy: { updatedAt: 'desc' },
    });
    const exact = candidates.filter(
      (chat) =>
        chat.participants.length === 2 &&
        chat.participants.every(
          (p) => p.userId === userId || p.userId === otherUserId,
        ),
    );

    const personal =
      exact[0] ??
      (await this.createChatWithParticipants({
        type: ChatType.personal,
        userIds: [userId, otherUserId],
      }));

    await this.prisma.chatParticipant.updateMany({
      where: { chatId: personal.id, userId, hiddenAt: { not: null } },
      data: { hiddenAt: null },
    });

    const viewer = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { role: true, extraRoles: true },
    });
    const viewerRole =
      viewer?.extraRoles.find((role) => isStudioRole(role)) ??
      (viewer && isStudioRole(viewer.role) ? viewer.role : viewer?.role);

    const chat = await this.prisma.chat.findUniqueOrThrow({
      where: { id: personal.id },
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

    return {
      id: chat.id,
      type: chat.type,
      typeLabel: CHAT_TYPE_LABELS[chat.type],
      title: this.resolveChatTitle(chat, viewerRole, userId),
      clientId: this.resolveClientId(chat, viewerRole),
      projectId: chat.projectId,
      unreadCount: 0,
      updatedAt: chat.updatedAt,
      lastMessage: null,
    };
  }

  /**
   * Match normalized RU phones to existing users (for device contacts UI).
   * Does not create accounts — unregistered numbers stay invite-via-SMS.
   */
  async matchPhones(actorId: string, phonesRaw: string[]) {
    const normalized = [
      ...new Set(
        phonesRaw
          .map((p) => this.normalizeRuPhone(p))
          .filter((p): p is string => !!p),
      ),
    ].slice(0, 500);

    if (normalized.length === 0) {
      return {
        matches: [] as Array<{
          phone: string;
          id: string;
          name: string;
          role: UserRole;
          roleLabel: string;
        }>,
      };
    }

    const last10Set = new Set(normalized.map((p) => p.slice(-10)));
    const requestPhoneByLast10 = new Map(
      normalized.map((p) => [p.slice(-10), p] as const),
    );

    // In-memory last-10 match: reliable across +7 / 8 / 7 / formatting quirks.
    const users = await this.prisma.user.findMany({
      where: { id: { not: actorId } },
      select: { id: true, name: true, phone: true, role: true },
      take: 5000,
    });

    const matches: Array<{
      phone: string;
      id: string;
      name: string;
      role: UserRole;
      roleLabel: string;
    }> = [];
    const seenIds = new Set<string>();

    for (const user of users) {
      const digits = (user.phone ?? '').replace(/\D/g, '').slice(-10);
      if (digits.length !== 10 || !last10Set.has(digits)) continue;
      if (seenIds.has(user.id)) continue;
      seenIds.add(user.id);
      const requestPhone = requestPhoneByLast10.get(digits) ?? `+7${digits}`;
      matches.push({
        phone: requestPhone,
        id: user.id,
        name: this.publicDisplayName(user, { revealPhone: true }),
        role: user.role,
        roleLabel: this.contactRoleLabel(user.role),
      });
    }

    return { matches };
  }

  /** Start personal chat by phone; create user if needed and send SMS invite. */
  async inviteByPhone(actorId: string, phoneRaw: string, name?: string) {
    const phone = this.normalizeRuPhone(phoneRaw);
    if (!phone) {
      throw new BadRequestException('Телефон в формате +7XXXXXXXXXX');
    }

    const actor = await this.prisma.user.findUnique({
      where: { id: actorId },
      select: { id: true, phone: true, name: true },
    });
    if (!actor) throw new NotFoundException('User not found');
    if (actor.phone === phone) {
      throw new BadRequestException('Нельзя пригласить себя');
    }

    const existing = await this.prisma.user.findUnique({
      where: { phone },
      select: { id: true },
    });
    const isNew = existing == null;

    const invitee = await this.prisma.user.upsert({
      where: { phone },
      update: name?.trim() ? { name: name.trim() } : {},
      create: {
        phone,
        name: name?.trim() || null,
        role: UserRole.client,
      },
      select: { id: true, phone: true, name: true },
    });

    const chat = await this.getOrCreatePersonalChat(actorId, invitee.id);

    // SMS invite only for brand-new accounts — existing users just get a DM.
    if (isNew) {
      const appUrl =
        this.configService.get<string>('APP_DOWNLOAD_URL') ??
        'https://davart.ru/app';
      const from = actor.name?.trim() || actor.phone || 'пользователь DAVart';
      await this.smsService.sendText(
        phone,
        `${from} приглашает вас в чат DAVart. Скачать: ${appUrl}`,
      );
    }

    return { ...chat, invited: isNew, phone: invitee.phone };
  }

  private normalizeRuPhone(phoneRaw: string): string | null {
    const digits = phoneRaw.replace(/\D/g, '');
    let phone = phoneRaw.trim();
    if (digits.length === 11 && digits.startsWith('8')) {
      phone = `+7${digits.slice(1)}`;
    } else if (digits.length === 11 && digits.startsWith('7')) {
      phone = `+${digits}`;
    } else if (digits.length === 10) {
      phone = `+7${digits}`;
    }
    return /^\+7\d{10}$/.test(phone) ? phone : null;
  }

  private contactRoleLabel(role: UserRole) {
    switch (role) {
      case UserRole.client:
        return 'Клиент';
      case UserRole.designer:
        return 'Дизайнер';
      case UserRole.surveyor:
        return 'Замерщик';
      case UserRole.complectator:
        return 'Менеджер';
      case UserRole.admin:
        return 'Админ';
      default:
        return 'Контакт';
    }
  }

  async getOtherParticipantIds(chatId: string, excludeUserId: string) {
    const participants = await this.prisma.chatParticipant.findMany({
      where: { chatId, userId: { not: excludeUserId } },
      select: { userId: true },
    });

    return participants.map((participant) => participant.userId);
  }

  async getMessages(userId: string, chatId: string, page = 1, limit = 30) {
    await this.ensureParticipant(userId, chatId);
    const chatIds = await this.personalThreadChatIds(userId, chatId);

    const skip = (page - 1) * limit;
    const [items, total] = await Promise.all([
      this.prisma.message.findMany({
        where: { chatId: { in: chatIds } },
        include: messageInclude,
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.message.count({ where: { chatId: { in: chatIds } } }),
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
    await this.ensureParticipant(userId, chatId, { unhide: true });
    this.validateMessagePayload(dto);

    if (
      dto.attachmentKey &&
      !dto.attachmentKey.startsWith(`chats/${userId}/attachments/`)
    ) {
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

    if (dto.replyToId) {
      const replyTarget = await this.prisma.message.findFirst({
        where: { id: dto.replyToId, chatId },
        select: { id: true },
      });
      if (!replyTarget) {
        throw new BadRequestException('Reply target not found in this chat');
      }
    }

    const threadIds = await this.personalThreadChatIds(userId, chatId);

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
          replyToId: dto.replyToId,
        },
        include: messageInclude,
      });

      await tx.chat.update({
        where: { id: chatId },
        data: { updatedAt: new Date() },
      });

      // A dismissed duplicate of the same 1:1 chat must open again too.
      await tx.chatParticipant.updateMany({
        where: { chatId: { in: threadIds }, userId: { not: userId } },
        data: { hiddenAt: null },
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

    if (chat.type === ChatType.support) {
      const client = chat.participants.find(
        (p) => p.user.role === UserRole.client,
      );
      if (client) {
        await this.syncStaffIntoSupportChat(
          chat.id,
          await this.listDutyStaffIds(),
        );
        await this.pruneSupportFieldStaffOnce(chat.id, client.user.id);
      }
    }

    const refreshed =
      chat.type === ChatType.support
        ? await this.prisma.chat.findUnique({
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
          })
        : chat;

    if (!refreshed) {
      throw new NotFoundException('Chat not found');
    }

    const viewer = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { role: true, extraRoles: true },
    });
    const viewerRoles = viewer ? allRolesOf(viewer) : [];
    const viewerIsStudio = hasStudioRole(viewerRoles);
    const viewerRole =
      viewer && hasSupportDutyRole(viewerRoles)
        ? UserRole.complectator
        : viewer?.role;

    const visibleParticipants = viewerIsStudio
      ? refreshed.participants
      : refreshed.participants.filter((p) => p.user.id === userId);

    return {
      id: refreshed.id,
      type: refreshed.type,
      typeLabel: CHAT_TYPE_LABELS[refreshed.type],
      title: this.resolveChatTitle(refreshed, viewerRole, userId),
      projectId: refreshed.projectId,
      projectName: refreshed.project?.name ?? null,
      clientId: this.resolveClientId(refreshed, viewerRole),
      participants: visibleParticipants.map((participant) => ({
        id: participant.user.id,
        name: this.publicDisplayName(participant.user),
        phone: canSeeContactPhone(viewerRoles) ? participant.user.phone : '',
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
        attachmentUrl = await this.storage.getDownloadUrl(
          message.attachmentKey,
        );
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
    await this.ensureParticipant(userId, chatId);
    const chatIds = await this.personalThreadChatIds(userId, chatId);

    await this.prisma.chatParticipant.updateMany({
      where: { userId, chatId: { in: chatIds } },
      data: { lastReadAt: new Date(), unreadCount: 0 },
    });

    return { chatId, readAt: new Date() };
  }

  async createAttachmentUploadUrl(userId: string, dto: AttachmentUploadUrlDto) {
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
      'audio/x-m4a',
      'audio/aac',
      'audio/mpeg',
      'audio/mp4a-latm',
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

  async uploadAttachment(
    userId: string,
    file: {
      originalname: string;
      mimetype: string;
      size: number;
      buffer: Buffer;
    },
  ) {
    if (!this.storage.isAvailable()) {
      throw new BadRequestException('File storage is not available');
    }
    if (file.size > 50 * 1024 * 1024) {
      throw new BadRequestException('File is too large (max 50 MB)');
    }

    const rawType = (file.mimetype || 'application/octet-stream').toLowerCase();
    const name = file.originalname.toLowerCase();
    const contentType =
      rawType === 'application/octet-stream' && name.endsWith('.m4a')
        ? 'audio/mp4'
        : rawType;
    this.assertAllowedAttachmentType(contentType);

    const attachmentId = randomUUID();
    const safeName = file.originalname.replace(/[^a-zA-Z0-9._-]/g, '_');
    const storageKey = `chats/${userId}/attachments/${attachmentId}/${safeName}`;
    await this.storage.uploadObject(storageKey, file.buffer, contentType);

    return {
      attachmentKey: storageKey,
      attachmentName: file.originalname,
      attachmentMime: contentType,
    };
  }

  async toggleReaction(
    userId: string,
    chatId: string,
    messageId: string,
    emoji: string,
  ) {
    await this.ensureParticipant(userId, chatId);
    const message = await this.prisma.message.findFirst({
      where: { id: messageId, chatId },
      select: { id: true },
    });
    if (!message) throw new NotFoundException('Message not found');

    const existing = await this.prisma.messageReaction.findUnique({
      where: {
        messageId_userId_emoji: { messageId, userId, emoji },
      },
    });
    if (existing) {
      await this.prisma.messageReaction.delete({ where: { id: existing.id } });
    } else {
      await this.prisma.messageReaction.create({
        data: { messageId, userId, emoji },
      });
    }

    const refreshed = await this.prisma.message.findUniqueOrThrow({
      where: { id: messageId },
      include: messageInclude,
    });
    return this.formatMessage(refreshed, userId);
  }

  async setPinned(
    userId: string,
    chatId: string,
    messageId: string,
    pinned: boolean,
  ) {
    await this.ensureParticipant(userId, chatId);
    const message = await this.prisma.message.findFirst({
      where: { id: messageId, chatId },
      select: { id: true },
    });
    if (!message) throw new NotFoundException('Message not found');

    if (pinned) {
      await this.prisma.$transaction([
        this.prisma.message.updateMany({
          where: { chatId, isPinned: true },
          data: { isPinned: false, pinnedAt: null },
        }),
        this.prisma.message.update({
          where: { id: messageId },
          data: { isPinned: true, pinnedAt: new Date() },
        }),
      ]);
    } else {
      await this.prisma.message.update({
        where: { id: messageId },
        data: { isPinned: false, pinnedAt: null },
      });
    }

    const refreshed = await this.prisma.message.findUniqueOrThrow({
      where: { id: messageId },
      include: messageInclude,
    });
    return this.formatMessage(refreshed, userId);
  }

  async forwardMessage(
    userId: string,
    chatId: string,
    messageId: string,
    targetChatId: string,
  ) {
    await this.ensureParticipant(userId, chatId);
    await this.ensureParticipant(userId, targetChatId);

    const source = await this.prisma.message.findFirst({
      where: { id: messageId, chatId },
    });
    if (!source) throw new NotFoundException('Message not found');

    const message = await this.prisma.$transaction(async (tx) => {
      const created = await tx.message.create({
        data: {
          chatId: targetChatId,
          senderId: userId,
          type: source.type,
          content: source.content,
          attachmentKey: source.attachmentKey,
          attachmentName: source.attachmentName,
          attachmentMime: source.attachmentMime,
          productId: source.productId,
        },
        include: messageInclude,
      });

      await tx.chat.update({
        where: { id: targetChatId },
        data: { updatedAt: new Date() },
      });

      await tx.chatParticipant.updateMany({
        where: { chatId: targetChatId, userId: { not: userId } },
        data: { hiddenAt: null, unreadCount: { increment: 1 } },
      });

      return created;
    });

    return this.formatMessage(message, userId);
  }

  async getPinnedMessage(userId: string, chatId: string) {
    await this.ensureParticipant(userId, chatId);
    const pinned = await this.prisma.message.findFirst({
      where: { chatId, isPinned: true },
      include: messageInclude,
      orderBy: { pinnedAt: 'desc' },
    });
    if (!pinned) return null;
    return this.formatMessage(pinned, userId);
  }

  private assertAllowedAttachmentType(contentType: string) {
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
      'audio/x-m4a',
      'audio/aac',
      'audio/mpeg',
      'audio/mp4a-latm',
      'video/mp4',
    ];
    if (!allowed.includes(contentType)) {
      throw new BadRequestException('This file type is not allowed');
    }
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

  /** Ensures client has a Davart support chat with duty staff as participants. */
  async ensureDavartChat(clientId: string) {
    await this.getOrCreateSupportChat(clientId);
  }

  /**
   * Staff opens a client's support thread.
   * Duty (manager/admin) join automatically; field staff only if already invited.
   */
  async openClientSupportChat(staffId: string, clientId: string) {
    await this.getOrCreateSupportChat(clientId);
    const chat = await this.prisma.chat.findFirst({
      where: {
        type: ChatType.support,
        participants: { some: { userId: clientId } },
      },
      select: { id: true },
    });
    if (!chat) {
      throw new NotFoundException('Support chat not found');
    }

    const staff = await this.prisma.user.findUnique({
      where: { id: staffId },
      select: { role: true, extraRoles: true },
    });
    const roles = staff ? allRolesOf(staff) : [];
    const already = await this.prisma.chatParticipant.findUnique({
      where: { chatId_userId: { chatId: chat.id, userId: staffId } },
    });

    if (!already) {
      if (!hasSupportDutyRole(roles)) {
        throw new ForbiddenException(
          'Ask a manager to add you to this client chat',
        );
      }
      await this.prisma.chatParticipant.create({
        data: { chatId: chat.id, userId: staffId },
      });
    }

    const items = await this.listChats(staffId);
    const item = items.find((row) => row.id === chat.id);
    if (item) return item;

    return {
      id: chat.id,
      type: ChatType.support,
      typeLabel: CHAT_TYPE_LABELS[ChatType.support],
      title: DAVART_CHAT_TITLE,
      projectId: null,
      unreadCount: 0,
      updatedAt: new Date(),
      lastMessage: null,
    };
  }

  /**
   * Manager/admin invites designer or surveyor into a client support chat.
   * History stays; everyone gets a system notice.
   */
  async addSupportParticipant(
    actorId: string,
    chatId: string,
    targetUserId: string,
  ) {
    const actor = await this.prisma.user.findUnique({
      where: { id: actorId },
      select: {
        id: true,
        name: true,
        phone: true,
        role: true,
        extraRoles: true,
      },
    });
    if (!actor || !hasSupportDutyRole(allRolesOf(actor))) {
      throw new ForbiddenException('Only managers can add staff to support');
    }

    const chat = await this.prisma.chat.findUnique({
      where: { id: chatId },
      include: {
        participants: {
          include: { user: { select: { id: true, role: true } } },
        },
      },
    });
    if (!chat || chat.type !== ChatType.support) {
      throw new BadRequestException('Only support chats accept staff invites');
    }

    await this.ensureParticipant(actorId, chatId);

    const target = await this.prisma.user.findUnique({
      where: { id: targetUserId },
      select: {
        id: true,
        name: true,
        phone: true,
        role: true,
        extraRoles: true,
      },
    });
    if (!target) {
      throw new NotFoundException('User not found');
    }
    const targetRoles = allRolesOf(target);
    const isField =
      targetRoles.includes(UserRole.designer) ||
      targetRoles.includes(UserRole.surveyor);
    if (!isField) {
      throw new BadRequestException('Can only add designer or surveyor');
    }

    const existing = await this.prisma.chatParticipant.findUnique({
      where: { chatId_userId: { chatId, userId: targetUserId } },
    });
    if (existing) {
      return {
        chat: await this.getChat(actorId, chatId),
        message: null,
      };
    }

    await this.prisma.chatParticipant.create({
      data: { chatId, userId: targetUserId },
    });

    // After first invite, skip one-shot prune so invited field staff stay.
    await this.redis.set(`${SUPPORT_ROSTER_REDIS_PREFIX}${chatId}`, '1');

    const actorName = this.publicDisplayName(actor, { revealPhone: true });
    const targetName = this.publicDisplayName(target, { revealPhone: true });
    const roleLabel =
      targetRoles.includes(UserRole.surveyor) &&
      !targetRoles.includes(UserRole.designer)
        ? 'замерщика'
        : 'дизайнера';

    const notice = await this.createSeedMessage({
      chatId,
      senderId: actorId,
      type: MessageType.text,
      content: `${actorName} добавил(а) ${roleLabel} ${targetName} в чат`,
    });

    return {
      chat: await this.getChat(actorId, chatId),
      message: await this.formatMessage(notice, actorId),
    };
  }

  /** Assign designer/surveyor on a project and invite them into client support + project chat. */
  async assignToClientProject(params: {
    actorId: string;
    projectId: string;
    designerId?: string | null;
    surveyorId?: string | null;
  }) {
    const actor = await this.prisma.user.findUnique({
      where: { id: params.actorId },
      select: {
        id: true,
        name: true,
        phone: true,
        role: true,
        extraRoles: true,
      },
    });
    if (!actor || !hasSupportDutyRole(allRolesOf(actor))) {
      throw new ForbiddenException('Only managers can assign project staff');
    }

    const project = await this.prisma.project.findFirst({
      where: { id: params.projectId, isShowcase: false },
      select: { id: true, name: true, userId: true },
    });
    if (!project) {
      throw new NotFoundException('Project not found');
    }

    const data: { designerId?: string | null; surveyorId?: string | null } = {};
    if (params.designerId !== undefined) data.designerId = params.designerId;
    if (params.surveyorId !== undefined) data.surveyorId = params.surveyorId;

    if (Object.keys(data).length > 0) {
      await this.prisma.project.update({
        where: { id: project.id },
        data,
      });
    }

    const projectChat = await this.ensureProjectChat(project.id);
    await this.getOrCreateSupportChat(project.userId);
    const supportChat = await this.prisma.chat.findFirst({
      where: {
        type: ChatType.support,
        participants: { some: { userId: project.userId } },
      },
      select: { id: true },
    });

    const inviteIds = [params.designerId, params.surveyorId].filter(
      (id): id is string => Boolean(id),
    );

    const notices: Array<{
      chatId: string;
      message: {
        type: string;
        content?: string | null;
        attachmentName?: string | null;
        sender?: { name?: string | null };
      };
    }> = [];

    for (const staffId of inviteIds) {
      if (supportChat) {
        const inSupport = await this.prisma.chatParticipant.findUnique({
          where: {
            chatId_userId: { chatId: supportChat.id, userId: staffId },
          },
        });
        if (!inSupport) {
          const { message } = await this.addSupportParticipant(
            params.actorId,
            supportChat.id,
            staffId,
          );
          if (message) {
            notices.push({
              chatId: supportChat.id,
              message,
            });
          }
        }
      }

      if (projectChat) {
        await this.prisma.chatParticipant.upsert({
          where: {
            chatId_userId: { chatId: projectChat.id, userId: staffId },
          },
          update: {},
          create: { chatId: projectChat.id, userId: staffId },
        });
      }
    }

    const projectResult = await this.prisma.project.findUnique({
      where: { id: project.id },
      select: {
        id: true,
        name: true,
        designerId: true,
        surveyorId: true,
        managerId: true,
      },
    });

    return { project: projectResult, notices };
  }

  /** Add duty staff (complectator/admin) to every support chat — not field roles. */
  async syncStaffIntoAllSupportChats(staffId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: staffId },
      select: { role: true, extraRoles: true },
    });
    if (!user || !hasSupportDutyRole(allRolesOf(user))) {
      return;
    }

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

  /** Create or reuse the project working chat; skip showcase. */
  async ensureProjectChat(projectId: string) {
    const project = await this.prisma.project.findUnique({
      where: { id: projectId },
      select: {
        id: true,
        name: true,
        userId: true,
        isShowcase: true,
        projectChatDismissed: true,
        designerId: true,
        managerId: true,
        surveyorId: true,
        members: { select: { userId: true } },
      },
    });
    if (!project) {
      throw new NotFoundException('Project not found');
    }
    if (project.isShowcase || project.projectChatDismissed) {
      return null;
    }

    const existing = await this.prisma.chat.findFirst({
      where: { projectId, type: ChatType.project },
      select: { id: true },
    });
    if (existing) {
      await this.syncProjectChatParticipants(existing.id, project);
      await this.ensureProjectWelcomeMessage(existing.id, {
        userId: project.userId,
        designerId: project.designerId,
        managerId: project.managerId,
      });
      return existing;
    }

    const userIds = this.collectProjectParticipantIds(project);
    const chat = await this.createChatWithParticipants({
      type: ChatType.project,
      projectId: project.id,
      title: project.name,
      userIds,
    });

    await this.ensureProjectWelcomeMessage(chat.id, {
      userId: project.userId,
      designerId: project.designerId,
      managerId: project.managerId,
    });

    return chat;
  }

  /** First system greeting for the client when a project chat appears. */
  private async ensureProjectWelcomeMessage(
    chatId: string,
    project: {
      userId: string;
      designerId: string | null;
      managerId: string | null;
    },
  ) {
    const existingMessage = await this.prisma.message.findFirst({
      where: { chatId },
      select: { id: true },
    });
    if (existingMessage) return;

    const duty = await this.listDutyStaffIds();
    const senderId =
      project.managerId ?? duty[0] ?? project.designerId ?? project.userId;

    await this.createSeedMessage({
      chatId,
      senderId,
      type: MessageType.text,
      content: PROJECT_WELCOME_MESSAGE,
    });

    if (project.userId !== senderId) {
      await this.pushService.sendToUser(project.userId, {
        title: DAVART_CHAT_TITLE,
        body: 'Добро пожаловать в чат DAVart дизайн 😌',
        data: { type: 'chat', chatId },
      });
    }
  }

  /** Open project chat for an actor who can access the project (client or assigned staff). */
  async openProjectChat(actorId: string, projectId: string) {
    const actor = await this.prisma.user.findUnique({
      where: { id: actorId },
      select: { role: true, extraRoles: true },
    });
    const roles = actor ? [actor.role, ...actor.extraRoles] : [];

    const project = await this.prisma.project.findFirst({
      where: {
        id: projectId,
        ...actorProjectAccessWhere(actorId, roles),
      },
      select: {
        id: true,
        name: true,
        userId: true,
        isShowcase: true,
        projectChatDismissed: true,
      },
    });
    if (!project) {
      throw new NotFoundException('Project not found');
    }
    if (project.isShowcase) {
      throw new BadRequestException('Showcase has no project chat');
    }
    if (project.projectChatDismissed) {
      throw new NotFoundException('Project chat not found');
    }

    const chat = await this.ensureProjectChat(projectId);
    if (!chat) {
      throw new NotFoundException('Project chat not found');
    }

    const mine = await this.prisma.chatParticipant.findUnique({
      where: { chatId_userId: { chatId: chat.id, userId: actorId } },
      select: { hiddenAt: true },
    });
    if (mine?.hiddenAt) {
      throw new NotFoundException('Project chat not found');
    }
    if (!mine) {
      await this.prisma.chatParticipant.create({
        data: { chatId: chat.id, userId: actorId },
      });
    }

    const items = await this.listChats(actorId);
    const item = items.find((row) => row.id === chat.id);
    if (item) return item;

    return {
      id: chat.id,
      type: ChatType.project,
      typeLabel: CHAT_TYPE_LABELS[ChatType.project],
      title: project.name,
      clientId: project.userId,
      projectId: project.id,
      unreadCount: 0,
      updatedAt: new Date(),
      lastMessage: null,
    };
  }

  async postProjectSystemMessage(projectId: string, content: string) {
    const chat = await this.ensureProjectChat(projectId);
    if (!chat) return;

    const project = await this.prisma.project.findUnique({
      where: { id: projectId },
      select: {
        userId: true,
        designerId: true,
        managerId: true,
      },
    });
    if (!project) return;

    const duty = await this.listDutyStaffIds();
    const senderId =
      project.managerId ?? duty[0] ?? project.designerId ?? project.userId;

    await this.createSeedMessage({
      chatId: chat.id,
      senderId,
      type: MessageType.text,
      content,
    });
  }

  async getOrCreateSupportChat(userId: string) {
    const viewer = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true, extraRoles: true },
    });
    if (!viewer) {
      throw new NotFoundException('User not found');
    }
    if (isStudioRole(viewer.role) || viewer.extraRoles.some(isStudioRole)) {
      throw new ForbiddenException(
        'Support inbox is per client account and is not shared with staff logins',
      );
    }

    const staffIds = await this.listDutyStaffIds();

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
                sender: {
                  select: { id: true, name: true, phone: true, role: true },
                },
              },
            },
          },
        },
      },
    });

    if (existing) {
      await this.syncStaffIntoSupportChat(existing.chat.id, staffIds);
      await this.pruneSupportFieldStaffOnce(existing.chat.id, userId);
      if (existing.chat.title !== DAVART_CHAT_TITLE) {
        await this.prisma.chat.update({
          where: { id: existing.chat.id },
          data: { title: DAVART_CHAT_TITLE },
        });
      }

      const lastMessage = existing.chat.messages[0];
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
    await this.redis.set(`${SUPPORT_ROSTER_REDIS_PREFIX}${chat.id}`, '1');

    const welcomeSenderId = staffIds[0] ?? userId;
    if (staffIds.length > 0) {
      await this.createSeedMessage({
        chatId: chat.id,
        senderId: welcomeSenderId,
        type: MessageType.text,
        content: 'Здравствуйте! Команда DAVart на связи.',
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
      where: { userId, isShowcase: false },
      orderBy: { createdAt: 'asc' },
    });

    if (project) {
      await this.ensureProjectChat(project.id);
      await this.postProjectSystemMessage(
        project.id,
        `Чат проекта «${project.name}» создан.`,
      );
    }

    return { message: 'Demo chats created', supportChatId: supportChat.id };
  }

  private async listDutyStaffIds(): Promise<string[]> {
    const staff = await this.prisma.user.findMany({
      where: {
        OR: [
          { role: { in: SUPPORT_DUTY_ROLES } },
          { extraRoles: { hasSome: SUPPORT_DUTY_ROLES } },
        ],
      },
      select: { id: true },
    });
    return staff.map((user) => user.id);
  }

  /**
   * One-shot cleanup: drop designers/surveyors from legacy mega-support chats.
   * After a manager invites field staff, redis flag stays set so they are kept.
   */
  private async pruneSupportFieldStaffOnce(
    chatId: string,
    clientId: string,
  ): Promise<void> {
    const key = `${SUPPORT_ROSTER_REDIS_PREFIX}${chatId}`;
    const done = await this.redis.get(key);
    if (done) return;

    const participants = await this.prisma.chatParticipant.findMany({
      where: { chatId },
      include: {
        user: { select: { id: true, role: true, extraRoles: true } },
      },
    });

    const removeIds: string[] = [];
    for (const row of participants) {
      if (row.userId === clientId) continue;
      const roles = allRolesOf(row.user);
      if (hasSupportDutyRole(roles)) continue;
      if (
        roles.includes(UserRole.designer) ||
        roles.includes(UserRole.surveyor) ||
        isStudioRole(row.user.role)
      ) {
        removeIds.push(row.userId);
      }
    }

    if (removeIds.length > 0) {
      await this.prisma.chatParticipant.deleteMany({
        where: { chatId, userId: { in: removeIds } },
      });
    }

    await this.redis.set(key, '1');
  }

  private collectProjectParticipantIds(project: {
    userId: string;
    designerId: string | null;
    managerId: string | null;
    surveyorId: string | null;
    members: { userId: string }[];
  }): string[] {
    return Array.from(
      new Set(
        [
          project.userId,
          project.designerId,
          project.managerId,
          project.surveyorId,
          ...project.members.map((m) => m.userId),
        ].filter((id): id is string => Boolean(id)),
      ),
    );
  }

  private async syncProjectChatParticipants(
    chatId: string,
    project: {
      userId: string;
      designerId: string | null;
      managerId: string | null;
      surveyorId: string | null;
      members: { userId: string }[];
    },
  ) {
    const userIds = this.collectProjectParticipantIds(project);
    for (const userId of userIds) {
      const existing = await this.prisma.chatParticipant.findUnique({
        where: { chatId_userId: { chatId, userId } },
        select: { hiddenAt: true },
      });
      if (existing?.hiddenAt) continue;
      await this.prisma.chatParticipant.upsert({
        where: { chatId_userId: { chatId, userId } },
        update: {},
        create: { chatId, userId },
      });
    }
  }

  /** Hide a chat for this user. A dismissed project chat is not created again. */
  async dismissChat(userId: string, chatId: string) {
    const participant = await this.prisma.chatParticipant.findUnique({
      where: { chatId_userId: { chatId, userId } },
      include: {
        chat: { select: { id: true, type: true, projectId: true } },
      },
    });
    if (!participant) {
      throw new NotFoundException('Chat not found');
    }
    if (participant.chat.type === ChatType.support) {
      throw new BadRequestException('Чат поддержки нельзя удалить');
    }

    if (
      participant.chat.type === ChatType.project &&
      participant.chat.projectId
    ) {
      const project = await this.prisma.project.findUnique({
        where: { id: participant.chat.projectId },
        select: { userId: true },
      });
      if (project?.userId === userId) {
        await this.prisma.project.update({
          where: { id: participant.chat.projectId },
          data: { projectChatDismissed: true },
        });
      }
    }

    await this.prisma.chatParticipant.update({
      where: { id: participant.id },
      data: { hiddenAt: new Date(), unreadCount: 0 },
    });

    return { message: 'Chat hidden' };
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
  }): Promise<MessageWithRelations> {
    const message = await this.prisma.message.create({
      data: {
        chatId: params.chatId,
        senderId: params.senderId,
        type: params.type,
        content: params.content,
      },
      include: messageInclude,
    });

    await this.prisma.$transaction([
      this.prisma.chat.update({
        where: { id: params.chatId },
        data: { updatedAt: new Date() },
      }),
      this.prisma.chatParticipant.updateMany({
        where: {
          chatId: params.chatId,
          userId: { not: params.senderId },
          hiddenAt: null,
        },
        data: { unreadCount: { increment: 1 } },
      }),
    ]);

    return message;
  }

  async assertParticipant(userId: string, chatId: string) {
    return this.ensureParticipant(userId, chatId);
  }

  /** Chat ids the viewer's open thread might be using for this 1:1 conversation. */
  listDeliveryChatIds(userId: string, chatId: string) {
    return this.personalThreadChatIds(userId, chatId);
  }

  /** One row per person: duplicate 1:1 chats are the same conversation. */
  private personalPeerKey(
    chat: {
      id: string;
      type: ChatType;
      participants?: Array<{ user: { id: string } }>;
    },
    userId: string,
  ) {
    if (chat.type !== ChatType.personal) return `chat:${chat.id}`;
    const others = (chat.participants ?? [])
      .map((participant) => participant.user.id)
      .filter((id) => id !== userId);
    if (others.length !== 1) return `chat:${chat.id}`;
    return `dm:${others[0]}`;
  }

  /** All exact 1:1 personal chats between the viewer and the other person. */
  private async personalThreadChatIds(userId: string, chatId: string) {
    const chat = await this.prisma.chat.findUnique({
      where: { id: chatId },
      select: {
        type: true,
        participants: { select: { userId: true } },
      },
    });
    if (!chat || chat.type !== ChatType.personal) return [chatId];
    const others = chat.participants
      .map((participant) => participant.userId)
      .filter((id) => id !== userId);
    if (others.length !== 1) return [chatId];
    const otherId = others[0];
    const related = await this.prisma.chat.findMany({
      where: {
        type: ChatType.personal,
        AND: [
          { participants: { some: { userId } } },
          { participants: { some: { userId: otherId } } },
        ],
      },
      select: { id: true, participants: { select: { userId: true } } },
    });
    const ids = related
      .filter(
        (row) =>
          row.participants.length === 2 &&
          row.participants.every(
            (participant) =>
              participant.userId === userId || participant.userId === otherId,
          ),
      )
      .map((row) => row.id);
    return ids.length > 0 ? ids : [chatId];
  }

  private async ensureParticipant(
    userId: string,
    chatId: string,
    options?: { unhide?: boolean },
  ) {
    const participant = await this.prisma.chatParticipant.findUnique({
      where: { chatId_userId: { chatId, userId } },
    });

    if (!participant) {
      throw new ForbiddenException('Access denied');
    }

    if (participant.hiddenAt) {
      if (!options?.unhide) {
        throw new ForbiddenException('Access denied');
      }
      await this.prisma.chatParticipant.update({
        where: { chatId_userId: { chatId, userId } },
        data: { hiddenAt: null },
      });
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
    if (chat.type === ChatType.personal && chat.participants && viewerId) {
      const other = chat.participants.find((p) => p.user.id !== viewerId);
      if (other) {
        return this.publicDisplayName(other.user, {
          revealPhone: canSeeContactPhone(viewerRole),
        });
      }
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

  /**
   * Phone is closed and push did not go out: deliver the text by SMS
   * so the message still reaches the person.
   */
  async notifyOfflineBySms(
    userId: string,
    message: {
      type: string;
      content?: string | null;
      attachmentName?: string | null;
      sender?: { name?: string | null };
    },
  ) {
    try {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { phone: true },
      });
      const phone = user?.phone?.trim();
      if (!phone || phone.startsWith('+7000')) return;
      const push = this.buildPushPayload(message);
      const text = `${push.title}: ${push.body}`.slice(0, 280);
      await this.smsService.sendText(phone, text);
    } catch (error) {
      this.logger.warn(`Offline SMS failed for ${userId}: ${error}`);
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
      title: senderName && senderName.length > 0 ? senderName : 'DAVart',
      body: preview.length > 0 ? preview : 'Новое сообщение',
    };
  }

  /** Re-label a formatted message payload for a specific websocket viewer. */
  asViewerMessage<T extends { sender?: { id: string }; isMine?: boolean }>(
    message: T,
    viewerId: string,
  ): T {
    const senderId = message.sender?.id;
    return {
      ...message,
      isMine: senderId === viewerId,
    };
  }

  private async formatMessage(message: MessageWithRelations, viewerId: string) {
    let attachmentUrl: string | null = null;
    if (message.attachmentKey && this.storage.isAvailable()) {
      attachmentUrl = await this.storage.getDownloadUrl(message.attachmentKey);
    }

    const reactionMap = new Map<string, { emoji: string; count: number; mine: boolean }>();
    for (const reaction of message.reactions ?? []) {
      const current = reactionMap.get(reaction.emoji) ?? {
        emoji: reaction.emoji,
        count: 0,
        mine: false,
      };
      current.count += 1;
      if (reaction.userId === viewerId) current.mine = true;
      reactionMap.set(reaction.emoji, current);
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
            imageUrl: resolveProductImageUrl({
              productId: message.product.id,
              imageUrl: message.product.imageUrl,
            }),
            slug: message.product.slug,
          }
        : null,
      replyTo: message.replyTo
        ? {
            id: message.replyTo.id,
            type: message.replyTo.type,
            content: message.replyTo.content,
            attachmentName: message.replyTo.attachmentName,
            senderName: this.publicDisplayName(message.replyTo.sender),
          }
        : null,
      reactions: [...reactionMap.values()],
      isPinned: message.isPinned,
      sender: {
        id: message.sender.id,
        name: this.publicDisplayName(message.sender),
      },
      isMine: message.senderId === viewerId,
      createdAt: message.createdAt,
    };
  }
}
