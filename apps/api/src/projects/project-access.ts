import { Prisma } from '@prisma/client';

/** Access: primary owner (`userId`) or any ProjectMember row. */
export function userProjectAccessWhere(
  userId: string,
): Prisma.ProjectWhereInput {
  return {
    isShowcase: false,
    OR: [{ userId }, { members: { some: { userId } } }],
  };
}

export function userCanAccessProjectWhere(
  userId: string,
  projectId: string,
): Prisma.ProjectWhereInput {
  return {
    id: projectId,
    ...userProjectAccessWhere(userId),
  };
}
