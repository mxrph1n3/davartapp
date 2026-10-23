import { Injectable, NotFoundException } from '@nestjs/common';
import { PortfolioKind, Prisma } from '@prisma/client';
import { hasStudioRole } from '../auth/roles';
import type { JwtPayload } from '../auth/decorators/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';

/** Tiles below the interior styles, after a larger gap. */
const KIND_TILES: Array<{ kind: PortfolioKind; label: string }> = [
  { kind: PortfolioKind.architecture, label: 'Архитектурный проект' },
  { kind: PortfolioKind.exterior, label: 'Экстерьер' },
  { kind: PortfolioKind.landscape, label: 'Ландшафт' },
];

const KIND_LABELS: Record<PortfolioKind, string> = {
  full: 'Полный',
  basic: 'Базовый',
  exterior: 'Экстерьер',
  architecture: 'Архитектурный',
  landscape: 'Ландшафт',
};

/** Shown number: internal suffixes for second cards of one project (15283-АР, 15299-Л) are hidden. */
const shownNumber = (number: string) => number.replace(/-(АР|Л)$/u, '');

export const MOSAIC_KEY = 'portfolio/_cover/mosaic.jpg';

const INTERIOR_KINDS = [PortfolioKind.full, PortfolioKind.basic];

export type PortfolioQuery = {
  style?: string;
  kind?: PortfolioKind;
  objectType?: string[];
  areaMin?: number;
  areaMax?: number;
  room?: string[];
};

const listInclude = {
  images: { orderBy: { sortOrder: 'asc' }, where: { isPlan: false } },
} satisfies Prisma.PortfolioProjectInclude;

@Injectable()
export class PortfolioService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  /** Drafts are visible to the studio only. */
  private visibility(viewer?: JwtPayload): Prisma.PortfolioProjectWhereInput {
    const studio =
      viewer && hasStudioRole([viewer.role, ...(viewer.extraRoles ?? [])]);
    return studio ? {} : { published: true };
  }

  private url(key: string | null | undefined) {
    return key ? this.storage.publicUrl(key) : null;
  }

  /** «Все проекты» collage, style tiles (only styles that have projects), kind tiles. */
  async tiles(viewer?: JwtPayload) {
    const visible = this.visibility(viewer);
    const [styles, styleCounts, kindCounts, collage] = await Promise.all([
      this.prisma.portfolioStyle.findMany({
        where: { NOT: { slug: { startsWith: 'kind:' } } },
        orderBy: { sortOrder: 'asc' },
      }),
      this.prisma.portfolioProject.groupBy({
        by: ['style'],
        where: { ...visible, kind: { in: INTERIOR_KINDS } },
        _count: true,
      }),
      this.prisma.portfolioProject.groupBy({
        by: ['kind'],
        where: visible,
        _count: true,
      }),
      this.prisma.portfolioImage.findMany({
        where: { isPlan: false, sortOrder: 0, project: visible },
        orderBy: { project: { sortOrder: 'asc' } },
        take: 9,
        select: { key: true },
      }),
    ]);
    const withProjects = new Set(styleCounts.map((row) => row.style));
    const kinds = new Set(kindCounts.map((row) => row.kind));
    const kindCovers = await Promise.all(
      KIND_TILES.filter((t) => kinds.has(t.kind)).map(async (t) => {
        // A cover picked by hand (manifest kindCovers) wins over the first project's render.
        const picked = await this.prisma.portfolioStyle.findUnique({
          where: { slug: `kind:${t.kind}` },
        });
        if (picked?.coverKey) {
          return {
            kind: t.kind,
            label: t.label,
            coverUrl: this.url(picked.coverKey),
          };
        }
        const cover = await this.prisma.portfolioImage.findFirst({
          where: { isPlan: false, project: { ...visible, kind: t.kind } },
          orderBy: [{ project: { sortOrder: 'asc' } }, { sortOrder: 'asc' }],
          select: { key: true },
        });
        return { kind: t.kind, label: t.label, coverUrl: this.url(cover?.key) };
      }),
    );
    return {
      /** Grid of tiny renders for the «Портфолио работ» cover (prepared by the import). */
      mosaicUrl: this.url(MOSAIC_KEY),
      collage: collage.map((image) => this.url(image.key)),
      styles: styles
        .filter((style) => withProjects.has(style.slug))
        .map((style) => ({
          slug: style.slug,
          label: style.label,
          coverUrl: this.url(style.coverKey),
        })),
      kinds: kindCovers,
    };
  }

  async list(query: PortfolioQuery, viewer?: JwtPayload) {
    const and: Prisma.PortfolioProjectWhereInput[] = [this.visibility(viewer)];
    if (query.style) and.push({ style: query.style });
    if (query.kind) {
      and.push({ kind: query.kind });
    } else if (query.style) {
      and.push({ kind: { in: INTERIOR_KINDS } });
    }
    if (query.objectType?.length)
      and.push({ objectType: { in: query.objectType } });
    if (query.areaMin != null) and.push({ area: { gte: query.areaMin } });
    if (query.areaMax != null) and.push({ area: { lt: query.areaMax } });
    if (query.room?.length) and.push({ rooms: { hasSome: query.room } });

    const projects = await this.prisma.portfolioProject.findMany({
      where: { AND: and },
      include: listInclude,
      orderBy: [{ sortOrder: 'asc' }, { number: 'desc' }],
    });
    const styleLabels = await this.styleLabels();
    return projects.map((p) => ({
      id: p.id,
      number: shownNumber(p.number),
      title: p.title,
      kind: p.kind,
      style: p.style,
      styleLabel: p.style ? (styleLabels.get(p.style) ?? null) : null,
      area: p.area,
      published: p.published,
      images: p.images.map((image) => this.url(image.key)),
    }));
  }

  /** Values for the filter sheet: object types, rooms. */
  async filters(viewer?: JwtPayload) {
    const projects = await this.prisma.portfolioProject.findMany({
      where: this.visibility(viewer),
      select: { objectType: true, rooms: true },
    });
    const count = (values: string[]) => {
      const map = new Map<string, number>();
      for (const v of values) map.set(v, (map.get(v) ?? 0) + 1);
      return [...map.entries()]
        .sort((a, b) => b[1] - a[1])
        .map(([value]) => value);
    };
    return {
      objectTypes: count(
        projects.flatMap((p) => (p.objectType ? [p.objectType] : [])),
      ),
      rooms: count(projects.flatMap((p) => p.rooms)).slice(0, 16),
      styles: [...(await this.styleLabels()).entries()].map(
        ([slug, label]) => ({
          slug,
          label,
        }),
      ),
    };
  }

  async get(id: string, viewer?: JwtPayload) {
    const project = await this.prisma.portfolioProject.findFirst({
      where: { id, ...this.visibility(viewer) },
      include: { images: { orderBy: { sortOrder: 'asc' } } },
    });
    if (!project) throw new NotFoundException('Project not found');
    const styleLabels = await this.styleLabels();
    const favorite = viewer
      ? (await this.prisma.portfolioFavorite.findUnique({
          where: { userId_projectId: { userId: viewer.sub, projectId: id } },
        })) != null
      : false;
    return {
      id: project.id,
      number: shownNumber(project.number),
      title: project.title,
      kind: project.kind,
      kindLabel: KIND_LABELS[project.kind],
      objectType: project.objectType,
      style: project.style,
      styleLabel: project.style
        ? (styleLabels.get(project.style) ?? null)
        : null,
      area: project.area,
      rooms: project.rooms,
      designer: project.designer,
      completedAt: project.completedAt,
      materialsCost: project.materialsCost
        ? Number(project.materialsCost)
        : null,
      description: project.description,
      inRealization: project.inRealization,
      published: project.published,
      favorite,
      images: project.images
        .filter((image) => !image.isPlan)
        .map((image) => ({
          url: this.url(image.key),
          room: image.room,
          width: image.width,
          height: image.height,
        })),
      plans: project.images
        .filter((image) => image.isPlan)
        .map((image) => this.url(image.key)),
    };
  }

  async setFavorite(userId: string, projectId: string, on: boolean) {
    if (on) {
      await this.prisma.portfolioFavorite.upsert({
        where: { userId_projectId: { userId, projectId } },
        update: {},
        create: { userId, projectId },
      });
    } else {
      await this.prisma.portfolioFavorite.deleteMany({
        where: { userId, projectId },
      });
    }
    return { favorite: on };
  }

  async favorites(userId: string) {
    const rows = await this.prisma.portfolioFavorite.findMany({
      where: { userId, project: { published: true } },
      orderBy: { createdAt: 'desc' },
      include: { project: { include: listInclude } },
    });
    const styleLabels = await this.styleLabels();
    return rows.map(({ project: p }) => ({
      id: p.id,
      number: shownNumber(p.number),
      title: p.title,
      kind: p.kind,
      style: p.style,
      styleLabel: p.style ? (styleLabels.get(p.style) ?? null) : null,
      area: p.area,
      published: p.published,
      images: p.images.map((image) => this.url(image.key)),
    }));
  }

  private async styleLabels() {
    const styles = await this.prisma.portfolioStyle.findMany({
      where: { NOT: { slug: { startsWith: 'kind:' } } },
      orderBy: { sortOrder: 'asc' },
    });
    return new Map(styles.map((s) => [s.slug, s.label]));
  }
}
