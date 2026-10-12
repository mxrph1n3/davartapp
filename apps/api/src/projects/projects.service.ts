import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  forwardRef,
} from '@nestjs/common';
import {
  Prisma,
  ProjectMemberRole,
  ProjectStatus,
  UserRole,
} from '@prisma/client';
import { canSeeContactPhone, isStudioRole } from '../auth/roles';
import { ChatService } from '../chat/chat.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  BriefPdfService,
  BRIEF_EDITABLE_STATUSES,
  PROJECT_STATUS_LABELS,
} from './brief-pdf.service';
import {
  emptyBriefAnswers,
  BRIEF_VALUE_LABELS,
  type BriefAnswers,
} from './brief-questionnaire';
import {
  CreateProjectDto,
  InviteProjectMemberDto,
  UpdateBriefDto,
} from './dto/projects.dto';
import {
  actorProjectAccessWhere,
  canAccessAnyClientProject,
} from './project-access';

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
    @Inject(forwardRef(() => ChatService))
    private readonly chatService: ChatService,
  ) {}

  async listForUser(userId: string) {
    const actor = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { role: true, extraRoles: true },
    });
    const roles = actor ? [actor.role, ...actor.extraRoles] : [];
    const hidePhones = !canSeeContactPhone(roles);

    const projects = await this.prisma.project.findMany({
      where: actorProjectAccessWhere(userId, roles),
      include: projectInclude,
      orderBy: { createdAt: 'asc' },
    });

    return projects.map((project) => this.formatProject(project, hidePhones));
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
    const actor = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { role: true, extraRoles: true },
    });
    const hidePhones = !canSeeContactPhone([
      ...(actor ? [actor.role, ...actor.extraRoles] : []),
    ]);
    const project = await this.findUserProject(userId, projectId);
    return this.formatProject(project, hidePhones);
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
    const name = dto.name?.trim() || (await this.nextProjectName());
    const project = await this.prisma.project.create({
      data: {
        userId,
        name,
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

    await this.chatService.ensureProjectChat(project.id);

    return this.formatProject(project);
  }

  async delete(userId: string, projectId: string) {
    const project = await this.prisma.project.findFirst({
      where: { id: projectId, userId, isShowcase: false },
      select: { id: true, status: true },
    });
    if (!project) {
      throw new NotFoundException('Project not found');
    }
    if (project.status !== ProjectStatus.brief_filling) {
      throw new ForbiddenException(
        'Удалить можно только проект на этапе «Бриф»',
      );
    }

    await this.prisma.chat.deleteMany({ where: { projectId: project.id } });
    await this.prisma.project.delete({ where: { id: project.id } });
    return { message: 'Project deleted' };
  }

  /** Human project number: «Проект №12» — client never picks the name. */
  private async nextProjectName(): Promise<string> {
    const rows = await this.prisma.$queryRaw<Array<{ next: number | bigint }>>`
      SELECT COALESCE(
        MAX(
          CASE
            WHEN name ~ '^Проект №([0-9]+)$'
            THEN (regexp_match(name, '^Проект №([0-9]+)$'))[1]::int
            ELSE NULL
          END
        ),
        0
      ) + 1 AS next
      FROM projects
    `;
    const next = Number(rows[0]?.next ?? 1);
    return `Проект №${next}`;
  }

  async listMembers(
    actorId: string,
    projectId: string,
    actorRole: UserRole,
    extraRoles: UserRole[] = [],
  ) {
    await this.assertCanViewMembers(actorId, projectId, actorRole);
    const hidePhones = !canSeeContactPhone([actorRole, ...extraRoles]);

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
        relation: m.relation,
        user: {
          id: m.user.id,
          phone: hidePhones ? '' : m.user.phone,
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
      update: {
        ...(dto.name?.trim() ? { name: dto.name.trim() } : {}),
      },
      create: {
        phone,
        name: dto.name?.trim() || null,
        role: UserRole.client,
      },
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
        relation: dto.relation?.trim() || null,
      },
      include: {
        user: { select: { id: true, phone: true, name: true, role: true } },
      },
    });

    await this.addMemberToProjectChats(projectId, invitee.id);

    return {
      id: member.id,
      role: member.role,
      relation: member.relation,
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
    if (project.isShowcase) {
      throw new ForbiddenException('Showcase portfolio has no questionnaire');
    }

    if (!project.brief) {
      const locked = !BRIEF_EDITABLE_STATUSES.includes(project.status);
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
    if (project.isShowcase) {
      throw new ForbiddenException('Showcase portfolio has no questionnaire');
    }

    if (!BRIEF_EDITABLE_STATUSES.includes(project.status)) {
      throw new ForbiddenException('Brief is locked');
    }

    if (project.brief?.isLocked) {
      throw new ForbiddenException('Brief is locked');
    }

    const derived = this.deriveLegacyFromAnswers(dto.answers);
    const projectFields = this.deriveProjectFieldsFromAnswers(dto.answers);

    const brief = await this.prisma.$transaction(async (tx) => {
      await tx.project.update({
        where: { id: projectId },
        data: {
          ...(projectFields.objectType !== undefined
            ? { objectType: projectFields.objectType }
            : {}),
          ...(projectFields.address !== undefined
            ? { address: projectFields.address }
            : {}),
          ...(projectFields.area !== undefined
            ? { area: projectFields.area }
            : {}),
          ...(projectFields.style !== undefined
            ? { style: projectFields.style }
            : {}),
        },
      });

      return tx.brief.upsert({
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
    });

    return this.formatBrief(brief, project);
  }

  async requestSurveyor(userId: string, projectId: string) {
    const project = await this.findUserProject(userId, projectId);
    if (project.isShowcase) {
      throw new ForbiddenException(
        'Showcase portfolio has no surveyor request',
      );
    }

    if (
      project.status !== ProjectStatus.brief_filling &&
      project.status !== ProjectStatus.measurement
    ) {
      throw new BadRequestException(
        'Вызов замерщика доступен на этапах «Бриф» и «Замер»',
      );
    }

    if (project.status === ProjectStatus.brief_filling) {
      await this.prisma.project.update({
        where: { id: projectId },
        data: { status: ProjectStatus.measurement },
      });
    }

    await this.chatService.postProjectSystemMessage(
      projectId,
      `Клиент запросил вызов замерщика по проекту «${project.name}».`,
    );

    const updated = await this.findUserProject(userId, projectId);
    return this.formatProject(updated);
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

    await this.prisma.project.update({
      where: { id: projectId },
      data: { status: ProjectStatus.in_progress },
    });

    await this.chatService.postProjectSystemMessage(
      projectId,
      `Проект «${project.name}» переведён на этап «Планировка».`,
    );

    return { message: 'Project moved to layout stage' };
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

    const clientProjects = await this.prisma.project.findMany({
      where: { userId, isShowcase: false },
      select: { id: true },
    });
    for (const row of clientProjects) {
      await this.chatService.ensureProjectChat(row.id);
    }

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
      update: { name: 'Павел Замерщик', role: 'surveyor' },
      create: {
        phone: '+79009999997',
        name: 'Павел Замерщик',
        role: 'surveyor',
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
    if (count >= 6) return;
    if (count > 0) {
      await this.prisma.project.deleteMany({ where: { isShowcase: true } });
    }

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
        rooms: [
          { name: 'Гостиная', type: 'living', area: 28 },
          { name: 'Спальня', type: 'bedroom', area: 16 },
          { name: 'Кухня', type: 'kitchen', area: 12 },
        ],
      },
      {
        name: 'Двушка на Арбате',
        address: 'Москва, Арбат',
        area: 58,
        style: 'Скандинавский',
        objectType: 'Квартира',
        status: ProjectStatus.completed,
        rooms: [
          { name: 'Гостиная', type: 'living', area: 22 },
          { name: 'Спальня', type: 'bedroom', area: 14 },
        ],
      },
      {
        name: 'Студия у метро',
        address: 'Москва, Бауманская',
        area: 38,
        style: 'Минимализм',
        objectType: 'Квартира',
        status: ProjectStatus.completed,
        rooms: [{ name: 'Студия', type: 'studio', area: 38 }],
      },
      {
        name: 'Офис на Белорусской',
        address: 'Москва, Тверская ул.',
        area: 240,
        style: 'Минимализм',
        objectType: 'Офис',
        status: ProjectStatus.completed,
        rooms: [
          { name: 'Open space', type: 'office', area: 160 },
          { name: 'Переговорная', type: 'meeting', area: 24 },
        ],
      },
      {
        name: 'Загородный дом',
        address: 'МО, Рублёво-Успенское ш.',
        area: 320,
        style: 'Прованс',
        objectType: 'Дом',
        status: ProjectStatus.completed,
        rooms: [
          { name: 'Гостиная', type: 'living', area: 48 },
          { name: 'Кухня', type: 'kitchen', area: 22 },
          { name: 'Спальня', type: 'bedroom', area: 20 },
          { name: 'Кабинет', type: 'office', area: 16 },
        ],
      },
      {
        name: 'Квартира с видом',
        address: 'Санкт-Петербург, Петроградка',
        area: 120,
        style: 'Лофт',
        objectType: 'Квартира',
        status: ProjectStatus.completed,
        rooms: [
          { name: 'Гостиная', type: 'living', area: 32 },
          { name: 'Спальня', type: 'bedroom', area: 18 },
          { name: 'Детская', type: 'kids', area: 14 },
          { name: 'Кабинет', type: 'office', area: 12 },
        ],
      },
    ] as const;

    for (const sample of samples) {
      const { rooms, ...projectFields } = sample;
      await this.prisma.project.create({
        data: {
          userId: studio.id,
          designerId: staff.designer.id,
          managerId: staff.manager.id,
          surveyorId: staff.surveyor.id,
          isShowcase: true,
          name: projectFields.name,
          address: projectFields.address,
          area: projectFields.area,
          style: projectFields.style,
          objectType: projectFields.objectType,
          status: projectFields.status,
          brief: {
            create: {
              style: sample.style,
              wishes: 'Пример реализованного проекта студии Davart',
              rooms: rooms,
              isLocked: true,
              lockedAt: new Date(),
            },
          },
        },
      });
    }
  }

  private async findUserProject(userId: string, projectId: string) {
    const actor = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { role: true, extraRoles: true },
    });
    const roles = actor ? [actor.role, ...actor.extraRoles] : [];

    const project = await this.prisma.project.findFirst({
      where: {
        id: projectId,
        ...actorProjectAccessWhere(userId, roles),
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
    await this.findUserProject(actorId, projectId);
    void actorRole;
  }

  private async assertCanManageMembers(
    actorId: string,
    projectId: string,
    actorRole: UserRole,
  ) {
    const project = await this.findUserProject(actorId, projectId);
    const actor = await this.prisma.user.findUnique({
      where: { id: actorId },
      select: { role: true, extraRoles: true },
    });
    const roles = actor ? [actor.role, ...actor.extraRoles] : [actorRole];

    if (canAccessAnyClientProject(roles) || isStudioRole(actorRole)) {
      return;
    }

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
    await this.chatService.ensureProjectChat(projectId);

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
    hidePhone = false,
  ) {
    if (!user) return null;
    return {
      id: user.id,
      name: user.name ?? (hidePhone ? 'DAVart' : user.phone),
      phone: hidePhone ? '' : user.phone,
    };
  }

  private formatProject(
    project: Prisma.ProjectGetPayload<{ include: typeof projectInclude }>,
    hidePhones = false,
  ) {
    return {
      id: project.id,
      userId: project.userId,
      name: project.name,
      address: project.address,
      area: project.area,
      style: project.style,
      objectType: project.objectType,
      startDate: project.startDate,
      status: project.status,
      statusLabel: PROJECT_STATUS_LABELS[project.status],
      isShowcase: project.isShowcase,
      designer: this.formatStaff(project.designer, hidePhones),
      manager: this.formatStaff(project.manager, hidePhones),
      surveyor: this.formatStaff(project.surveyor, hidePhones),
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

  private deriveProjectFieldsFromAnswers(answers?: BriefAnswers) {
    const general = answers?.general ?? {};
    const objectTypeId = general.objectType?.trim();
    const objectType = objectTypeId
      ? (BRIEF_VALUE_LABELS.objectType?.[objectTypeId] ?? objectTypeId)
      : undefined;
    const address = general.address?.trim() || undefined;
    const areaRaw = general.area?.replace(/\s/g, '').replace(',', '.');
    const areaParsed = areaRaw ? Number.parseFloat(areaRaw) : undefined;
    const area = Number.isFinite(areaParsed) ? areaParsed : undefined;
    const styleIds = (general.likedStyles ?? '')
      .split(/[,;\s]+/)
      .map((id) => id.trim())
      .filter(Boolean);
    const styleLabels = styleIds
      .map((id) => BRIEF_VALUE_LABELS.likedStyles?.[id] ?? id)
      .filter(Boolean);
    const custom = general.likedStylesCustom?.trim();
    const style =
      [...styleLabels, ...(custom ? [custom] : [])].join(', ') || undefined;

    return {
      objectType,
      address,
      area,
      style,
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
      brief.isLocked || !BRIEF_EDITABLE_STATUSES.includes(project.status);

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
