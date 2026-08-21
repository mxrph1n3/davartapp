import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  Prisma,
  ProjectMemberRole,
  ProjectStatus,
  UserRole,
} from '@prisma/client';
import { isStudioRole } from '../auth/roles';
import { PrismaService } from '../prisma/prisma.service';
import { BriefPdfService, PROJECT_STATUS_LABELS } from './brief-pdf.service';
import {
  emptyBriefAnswers,
  type BriefAnswers,
} from './brief-questionnaire';
import {
  CreateProjectDto,
  InviteProjectMemberDto,
  UpdateBriefDto,
} from './dto/projects.dto';
import { userProjectAccessWhere } from './project-access';

const staffSelect = { id: true, name: true, phone: true } as const;

const projectInclude = {
  designer: { select: staffSelect },
  manager: { select: staffSelect },
  surveyor: { select: staffSelect },
  brief: true,
} satisfies Prisma.ProjectInclude;

function normalizePhone(phone: string): string {
  const digits = phone.replace(/\D/g, '');
  if (digits.length === 11 && digits.startsWith('8')) {
    return `+7${digits.slice(1)}`;
  }
  if (digits.length === 11 && digits.startsWith('7')) {
    return `+${digits}`;
  }
  if (digits.length === 10) {
    return `+7${digits}`;
  }
  return phone.startsWith('+') ? phone : `+${digits}`;
}

@Injectable()
export class ProjectsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly briefPdf: BriefPdfService,
  ) {}

  async listForUser(userId: string) {
    const projects = await this.prisma.project.findMany({
      where: userProjectAccessWhere(userId),
      include: projectInclude,
      orderBy: { updatedAt: 'desc' },
    });

    return projects.map((project) => this.formatProject(project));
  }

  async listShowcase() {
    await this.ensureShowcaseProjects();
    const projects = await this.prisma.project.findMany({
      where: { isShowcase: true },
      include: projectInclude,
      orderBy: { updatedAt: 'desc' },
      take: 12,
    });
    return projects.map((project) => this.formatProject(project));
  }

  async getById(userId: string, projectId: string) {
    const project = await this.findUserProject(userId, projectId);
    return this.formatProject(project);
  }

  async getShowcaseById(projectId: string) {
    const project = await this.prisma.project.findFirst({
      where: { id: projectId, isShowcase: true },
      include: projectInclude,
    });
    if (!project) {
      throw new NotFoundException('Project not found');
    }
    return this.formatProject(project);
  }

  async create(userId: string, dto: CreateProjectDto) {
    const project = await this.prisma.project.create({
      data: {
        userId,
        name: dto.name.trim(),
        address: dto.address?.trim() || null,
        area: dto.area,
        style: dto.style?.trim() || null,
        objectType: dto.objectType?.trim() || null,
        status: ProjectStatus.brief_filling,
        brief: {
          create: {
            style: dto.style?.trim() || null,
            rooms: [],
          },
        },
        members: {
          create: {
            userId,
            role: ProjectMemberRole.owner,
          },
        },
      },
      include: projectInclude,
    });

    return this.formatProject(project);
  }

  async listMembers(actorId: string, projectId: string, actorRole: UserRole) {
    await this.assertCanViewMembers(actorId, projectId, actorRole);

    const members = await this.prisma.projectMember.findMany({
      where: { projectId },
      include: {
        user: { select: { id: true, phone: true, name: true, role: true } },
      },
      orderBy: [{ role: 'asc' }, { createdAt: 'asc' }],
    });

    return {
      items: members.map((m) => ({
        id: m.id,
        role: m.role,
        user: {
          id: m.user.id,
          phone: m.user.phone,
          name: m.user.name,
          userRole: m.user.role,
        },
        createdAt: m.createdAt,
      })),
    };
  }

  async inviteMember(
    actorId: string,
    projectId: string,
    actorRole: UserRole,
    dto: InviteProjectMemberDto,
  ) {
    await this.assertCanManageMembers(actorId, projectId, actorRole);

    const phone = normalizePhone(dto.phone);
    if (!/^\+7\d{10}$/.test(phone)) {
      throw new BadRequestException('Invalid phone number');
    }

    const invitee = await this.prisma.user.upsert({
      where: { phone },
      update: {},
      create: { phone, role: UserRole.client },
    });

    if (invitee.id === actorId) {
      throw new BadRequestException('Cannot invite yourself');
    }

    const memberRole = dto.role ?? ProjectMemberRole.member;

    const existing = await this.prisma.projectMember.findUnique({
      where: {
        projectId_userId: { projectId, userId: invitee.id },
      },
    });
    if (existing) {
      throw new BadRequestException('User is already a project member');
    }

    const project = await this.prisma.project.findUnique({
      where: { id: projectId },
      select: { userId: true },
    });
    if (project?.userId === invitee.id) {
      throw new BadRequestException('User is already the project owner');
    }

    const member = await this.prisma.projectMember.create({
      data: {
        projectId,
        userId: invitee.id,
        role: memberRole,
      },
      include: {
        user: { select: { id: true, phone: true, name: true, role: true } },
      },
    });

    await this.addMemberToProjectChats(projectId, invitee.id);

    return {
      id: member.id,
      role: member.role,
      user: {
        id: member.user.id,
        phone: member.user.phone,
        name: member.user.name,
        userRole: member.user.role,
      },
      createdAt: member.createdAt,
    };
  }

  async removeMember(
    actorId: string,
    projectId: string,
    actorRole: UserRole,
    memberUserId: string,
  ) {
    await this.assertCanManageMembers(actorId, projectId, actorRole);

    const project = await this.prisma.project.findUnique({
      where: { id: projectId },
      select: { userId: true },
    });
    if (!project) {
      throw new NotFoundException('Project not found');
    }

    if (project.userId === memberUserId) {
      throw new BadRequestException('Cannot remove primary project owner');
    }

    const member = await this.prisma.projectMember.findUnique({
      where: {
        projectId_userId: { projectId, userId: memberUserId },
      },
    });
    if (!member) {
      throw new NotFoundException('Member not found');
    }
    if (member.role === ProjectMemberRole.owner) {
      throw new BadRequestException('Cannot remove project owner');
    }

    await this.prisma.projectMember.delete({ where: { id: member.id } });
    return { removed: true };
  }

  async getBrief(userId: string, projectId: string) {
    const project = await this.findUserProject(userId, projectId);

    if (!project.brief) {
      const locked = project.status !== ProjectStatus.brief_filling;
      return {
        id: null,
        style: null,
        budget: null,
        wishes: null,
        rooms: [],
        answers: emptyBriefAnswers(),
        isLocked: locked,
        lockedAt: null,
        updatedAt: project.updatedAt,
      };
    }

    return this.formatBrief(project.brief, project);
  }

  async updateBrief(userId: string, projectId: string, dto: UpdateBriefDto) {
    const project = await this.findUserProject(userId, projectId);

    if (project.status !== ProjectStatus.brief_filling) {
      throw new ForbiddenException('Brief is locked');
    }

    if (project.brief?.isLocked) {
      throw new ForbiddenException('Brief is locked');
    }

    const derived = this.deriveLegacyFromAnswers(dto.answers as BriefAnswers | undefined);

    const brief = await this.prisma.brief.upsert({
      where: { projectId },
      update: {
        style: dto.style ?? derived.style,
        budget: dto.budget ?? derived.budget,
        wishes: dto.wishes ?? derived.wishes,
        rooms: dto.rooms as unknown as Prisma.InputJsonValue,
        answers:
          dto.answers === undefined
            ? undefined
            : (dto.answers as Prisma.InputJsonValue),
      },
      create: {
        projectId,
        style: dto.style ?? derived.style,
        budget: dto.budget ?? derived.budget,
        wishes: dto.wishes ?? derived.wishes,
        rooms: dto.rooms as unknown as Prisma.InputJsonValue,
        answers:
          dto.answers === undefined
            ? undefined
            : (dto.answers as Prisma.InputJsonValue),
      },
    });

    return this.formatBrief(brief, project);
  }

  async generateBriefPdf(userId: string, projectId: string): Promise<Buffer> {
    const project = await this.findUserProject(userId, projectId);

    if (!project.brief) {
      throw new NotFoundException('Brief not found');
    }

    const rooms = Array.isArray(project.brief.rooms)
      ? (project.brief.rooms as Array<{
          name: string;
          type?: string;
          area?: number;
        }>)
      : [];

    return this.briefPdf.generate({
      projectName: project.name,
      address: project.address,
      style: project.brief.style,
      budget: project.brief.budget ? Number(project.brief.budget) : null,
      wishes: project.brief.wishes,
      rooms,
      answers: (project.brief.answers as BriefAnswers | null) ?? null,
    });
  }

  async startWork(projectId: string) {
    const project = await this.prisma.project.findUnique({
      where: { id: projectId },
      include: { brief: true },
    });

    if (!project) {
      throw new NotFoundException('Project not found');
    }

    await this.prisma.$transaction([
      this.prisma.project.update({
        where: { id: projectId },
        data: { status: ProjectStatus.in_progress },
      }),
      this.prisma.brief.updateMany({
        where: { projectId },
        data: { isLocked: true, lockedAt: new Date() },
      }),
    ]);

    return { message: 'Project started, brief locked' };
  }

  async seedDemoProjects(userId: string) {
    const existing = await this.prisma.project.count({
      where: { userId, isShowcase: false },
    });
    if (existing > 0) {
      await this.ensureShowcaseProjects();
      return { message: 'Demo projects already exist' };
    }

    const staff = await this.ensureStaffUsers();

    await this.prisma.project.create({
      data: {
        userId,
        designerId: staff.designer.id,
        managerId: staff.manager.id,
        surveyorId: staff.surveyor.id,
        name: 'Квартира ЖК Skyline',
        address: 'Москва, ул. Примерная, 10',
        area: 85,
        style: 'Сканди',
        objectType: 'Квартира',
        status: ProjectStatus.brief_filling,
        members: {
          create: { userId, role: ProjectMemberRole.owner },
        },
        brief: {
          create: {
            style: 'Сканди',
            budget: 2500000,
            wishes: 'Светлое пространство, много дерева',
            rooms: [
              { name: 'Гостиная', type: 'living', area: 25 },
              { name: 'Спальня', type: 'bedroom', area: 18 },
            ],
          },
        },
      },
    });

    await this.prisma.project.create({
      data: {
        userId,
        designerId: staff.designer.id,
        managerId: staff.manager.id,
        surveyorId: staff.surveyor.id,
        name: 'Дом в Подмосковье',
        address: 'МО, д. Примерное',
        area: 180,
        style: 'Лофт',
        objectType: 'Дом',
        status: ProjectStatus.in_progress,
        members: {
          create: { userId, role: ProjectMemberRole.owner },
        },
        brief: {
          create: {
            style: 'Лофт',
            budget: 5000000,
            wishes: 'Открытая планировка',
            rooms: [{ name: 'Кухня-гостиная', type: 'open', area: 45 }],
            isLocked: true,
            lockedAt: new Date(),
          },
        },
      },
    });

    await this.ensureShowcaseProjects();
    return { message: 'Demo projects created' };
  }

  private async ensureStaffUsers() {
    const designer = await this.prisma.user.upsert({
      where: { phone: '+79009999999' },
      update: { name: 'Анна Дизайнер', role: 'designer' },
      create: {
        phone: '+79009999999',
        name: 'Анна Дизайнер',
        role: 'designer',
      },
    });
    const manager = await this.prisma.user.upsert({
      where: { phone: '+79009999998' },
      update: { name: 'Ирина Менеджер', role: 'complectator' },
      create: {
        phone: '+79009999998',
        name: 'Ирина Менеджер',
        role: 'complectator',
      },
    });
    const surveyor = await this.prisma.user.upsert({
      where: { phone: '+79009999997' },
      update: { name: 'Павел Замерщик', role: 'complectator' },
      create: {
        phone: '+79009999997',
        name: 'Павел Замерщик',
        role: 'complectator',
      },
    });
    await this.prisma.user.upsert({
      where: { phone: '+79009999990' },
      update: { name: 'Artur', role: 'admin' },
      create: {
        phone: '+79009999990',
        name: 'Artur',
        role: 'admin',
      },
    });
    return { designer, manager, surveyor };
  }

  private async ensureShowcaseProjects() {
    const count = await this.prisma.project.count({
      where: { isShowcase: true },
    });
    if (count > 0) return;

    const studio = await this.prisma.user.upsert({
      where: { phone: '+79000000001' },
      update: { name: 'Davart Studio' },
      create: { phone: '+79000000001', name: 'Davart Studio' },
    });
    const staff = await this.ensureStaffUsers();

    const samples = [
      {
        name: 'Квартира на Патриарших',
        address: 'Москва, Патриаршие пруды',
        area: 92,
        style: 'Современная классика',
        objectType: 'Квартира',
        status: ProjectStatus.completed,
      },
      {
        name: 'Офис на Белорусской',
        address: 'Москва, Тверская ул.',
        area: 240,
        style: 'Минимализм',
        objectType: 'Офис',
        status: ProjectStatus.completed,
      },
      {
        name: 'Загородный дом',
        address: 'МО, Рублёво-Успенское ш.',
        area: 320,
        style: 'Ваби-саби',
        objectType: 'Дом',
        status: ProjectStatus.completed,
      },
    ] as const;

    for (const sample of samples) {
      await this.prisma.project.create({
        data: {
          userId: studio.id,
          designerId: staff.designer.id,
          managerId: staff.manager.id,
          surveyorId: staff.surveyor.id,
          isShowcase: true,
          ...sample,
          brief: {
            create: {
              style: sample.style,
              wishes: 'Пример реализованного проекта студии Davart',
              rooms: [],
              isLocked: true,
              lockedAt: new Date(),
            },
          },
        },
      });
    }
  }

  private async findUserProject(userId: string, projectId: string) {
    const project = await this.prisma.project.findFirst({
      where: {
        id: projectId,
        ...userProjectAccessWhere(userId),
      },
      include: projectInclude,
    });

    if (!project) {
      throw new NotFoundException('Project not found');
    }

    return project;
  }

  private async assertCanViewMembers(
    actorId: string,
    projectId: string,
    actorRole: UserRole,
  ) {
    if (isStudioRole(actorRole)) {
      const project = await this.prisma.project.findFirst({
        where: { id: projectId, isShowcase: false },
        select: { id: true },
      });
      if (!project) throw new NotFoundException('Project not found');
      return;
    }
    await this.findUserProject(actorId, projectId);
  }

  private async assertCanManageMembers(
    actorId: string,
    projectId: string,
    actorRole: UserRole,
  ) {
    if (isStudioRole(actorRole)) {
      const project = await this.prisma.project.findFirst({
        where: { id: projectId, isShowcase: false },
        select: { id: true },
      });
      if (!project) throw new NotFoundException('Project not found');
      return;
    }

    const project = await this.findUserProject(actorId, projectId);
    const membership = await this.prisma.projectMember.findUnique({
      where: {
        projectId_userId: { projectId, userId: actorId },
      },
    });

    const isOwner =
      project.userId === actorId ||
      membership?.role === ProjectMemberRole.owner;

    if (!isOwner) {
      throw new ForbiddenException('Only project owner can manage members');
    }
  }

  private async addMemberToProjectChats(projectId: string, userId: string) {
    const chats = await this.prisma.chat.findMany({
      where: { projectId, type: 'project' },
      select: { id: true },
    });

    for (const chat of chats) {
      await this.prisma.chatParticipant.upsert({
        where: {
          chatId_userId: { chatId: chat.id, userId },
        },
        update: {},
        create: { chatId: chat.id, userId },
      });
    }
  }

  private formatStaff(
    user: { id: string; name: string | null; phone: string } | null,
  ) {
    if (!user) return null;
    return {
      id: user.id,
      name: user.name ?? user.phone,
      phone: user.phone,
    };
  }

  private formatProject(
    project: Prisma.ProjectGetPayload<{ include: typeof projectInclude }>,
  ) {
    return {
      id: project.id,
      name: project.name,
      address: project.address,
      area: project.area,
      style: project.style,
      objectType: project.objectType,
      startDate: project.startDate,
      status: project.status,
      statusLabel: PROJECT_STATUS_LABELS[project.status],
      isShowcase: project.isShowcase,
      designer: this.formatStaff(project.designer),
      manager: this.formatStaff(project.manager),
      surveyor: this.formatStaff(project.surveyor),
      brief: project.brief ? this.formatBrief(project.brief, project) : null,
      createdAt: project.createdAt,
      updatedAt: project.updatedAt,
    };
  }

  private deriveLegacyFromAnswers(answers?: BriefAnswers) {
    const general = answers?.general ?? {};
    const budgetRaw = general.budget?.replace(/\s/g, '').replace(',', '.');
    const budget = budgetRaw ? Number.parseFloat(budgetRaw) : undefined;
    return {
      style: general.likedStyles?.trim() || undefined,
      budget: Number.isFinite(budget) ? budget : undefined,
      wishes: general.details?.trim() || undefined,
    };
  }

  private formatBrief(
    brief: {
      id: string;
      style: string | null;
      budget: Prisma.Decimal | null;
      wishes: string | null;
      rooms: Prisma.JsonValue;
      answers: Prisma.JsonValue | null;
      isLocked: boolean;
      lockedAt: Date | null;
      updatedAt: Date;
    },
    project: { status: ProjectStatus },
  ) {
    const locked =
      brief.isLocked || project.status !== ProjectStatus.brief_filling;

    return {
      id: brief.id,
      style: brief.style,
      budget: brief.budget ? Number(brief.budget) : null,
      wishes: brief.wishes,
      rooms: brief.rooms ?? [],
      answers: brief.answers ?? emptyBriefAnswers(),
      isLocked: locked,
      lockedAt: brief.lockedAt,
      updatedAt: brief.updatedAt,
    };
  }
}
