import { Inject, Injectable, Logger, forwardRef } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { ChatGateway } from '../chat/chat.gateway';
import { PrismaService } from '../prisma/prisma.service';
import { PushService, type PushPayload } from '../push/push.service';

export type LiveEvent = 'cart' | 'order' | 'project' | 'document';

@Injectable()
export class LiveSyncService {
  private readonly logger = new Logger(LiveSyncService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly pushService: PushService,
    @Inject(forwardRef(() => ChatGateway))
    private readonly chatGateway: ChatGateway,
  ) {}

  /** Tell everyone who can see this project to refetch one screen. */
  async publish(
    projectId: string,
    event: LiveEvent,
    extra: Record<string, string> = {},
  ) {
    try {
      const userIds = await this.audience(projectId);
      this.chatGateway.publishDomain(userIds, event, { projectId, ...extra });
    } catch (error) {
      this.logger.warn(`Live ${event} for ${projectId} failed: ${error}`);
    }
  }

  /** Closed-app alert for the project owner. Open apps already get the socket. */
  async pushOwner(projectId: string, payload: PushPayload) {
    try {
      const project = await this.prisma.project.findUnique({
        where: { id: projectId },
        select: { userId: true },
      });
      if (!project) return;
      await this.pushService.sendToUser(project.userId, payload);
    } catch (error) {
      this.logger.warn(`Push for ${projectId} failed: ${error}`);
    }
  }

  private async audience(projectId: string): Promise<string[]> {
    const project = await this.prisma.project.findUnique({
      where: { id: projectId },
      select: {
        userId: true,
        designerId: true,
        managerId: true,
        surveyorId: true,
        members: { select: { userId: true } },
      },
    });
    if (!project) return [];

    const ids = new Set<string>([
      project.userId,
      ...project.members.map((member) => member.userId),
    ]);
    for (const id of [
      project.designerId,
      project.managerId,
      project.surveyorId,
    ]) {
      if (id) ids.add(id);
    }

    const managers = await this.prisma.user.findMany({
      where: {
        OR: [
          { role: { in: [UserRole.admin, UserRole.complectator] } },
          {
            extraRoles: {
              hasSome: [UserRole.admin, UserRole.complectator],
            },
          },
        ],
      },
      select: { id: true },
    });
    for (const manager of managers) ids.add(manager.id);
    return [...ids];
  }
}
