import { Prisma, UserRole } from '@prisma/client';
import { canSeeContactPhone, hasStudioRole } from '../auth/roles';

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

/** Studio assignment on a project (designer / manager / surveyor / member). */
export function staffAssignedToProjectWhere(
  staffId: string,
): Prisma.ProjectWhereInput {
  return {
    isShowcase: false,
    OR: [
      { designerId: staffId },
      { managerId: staffId },
      { surveyorId: staffId },
      { members: { some: { userId: staffId } } },
    ],
  };
}

/**
 * List/detail access for the signed-in actor:
 * - complectator/admin → all real projects
 * - designer/surveyor → assigned only
 * - client → owned / member
 */
export function actorProjectAccessWhere(
  userId: string,
  roles: UserRole[],
): Prisma.ProjectWhereInput {
  if (canAccessAnyClientProject(roles)) {
    return { isShowcase: false };
  }
  if (hasStudioRole(roles)) {
    return staffAssignedToProjectWhere(userId);
  }
  return userProjectAccessWhere(userId);
}

/** Client whose projects this staff member is assigned to. */
export function clientLinkedToStaffWhere(
  staffId: string,
): Prisma.UserWhereInput {
  return {
    role: UserRole.client,
    OR: [
      {
        clientProjects: {
          some: {
            isShowcase: false,
            OR: [
              { designerId: staffId },
              { managerId: staffId },
              { surveyorId: staffId },
              { members: { some: { userId: staffId } } },
            ],
          },
        },
      },
      {
        projectMemberships: {
          some: {
            project: {
              isShowcase: false,
              OR: [
                { designerId: staffId },
                { managerId: staffId },
                { surveyorId: staffId },
                { members: { some: { userId: staffId } } },
              ],
            },
          },
        },
      },
    ],
  };
}

/** Managers/admins see all non-showcase projects; others only assigned. */
export function canAccessAnyClientProject(roles: UserRole[]): boolean {
  return canSeeContactPhone(roles) || roles.includes(UserRole.admin);
}
