import { UserRole } from '@prisma/client';

/** Field / CRM roles that use the studio (staff) shell and /staff APIs. */
export const STUDIO_ROLES: UserRole[] = [
  UserRole.designer,
  UserRole.complectator,
  UserRole.surveyor,
  UserRole.admin,
];

const ROLE_RANK: UserRole[] = [
  UserRole.admin,
  UserRole.designer,
  UserRole.complectator,
  UserRole.surveyor,
  UserRole.client,
];

export function uniqueRoles(roles: UserRole[]): UserRole[] {
  return ROLE_RANK.filter((role) => roles.includes(role));
}

export function primaryRoleOf(roles: UserRole[]): UserRole {
  const unique = uniqueRoles(roles);
  return unique[0] ?? UserRole.client;
}

export function extraRolesOf(roles: UserRole[]): UserRole[] {
  const unique = uniqueRoles(roles);
  return unique.slice(1);
}

export function allRolesOf(user: {
  role: UserRole;
  extraRoles?: UserRole[] | null;
}): UserRole[] {
  return uniqueRoles([user.role, ...(user.extraRoles ?? [])]);
}

export function isStudioRole(
  role: UserRole | string | null | undefined,
): boolean {
  return (
    role === UserRole.designer ||
    role === UserRole.complectator ||
    role === UserRole.surveyor ||
    role === UserRole.admin
  );
}

export function hasStudioRole(roles: UserRole[]): boolean {
  return roles.some((role) => isStudioRole(role));
}

export function isAdminRole(role: UserRole | string | null | undefined): boolean {
  return role === UserRole.admin;
}

export function canSeeContactPhone(
  roleOrRoles: UserRole | string | null | undefined | UserRole[],
): boolean {
  const roles = Array.isArray(roleOrRoles)
    ? roleOrRoles
    : roleOrRoles
      ? [roleOrRoles as UserRole]
      : [];
  return (
    roles.includes(UserRole.complectator) || roles.includes(UserRole.admin)
  );
}

/** Complectators / admins always sit in client support (DAVart) chats. */
export const SUPPORT_DUTY_ROLES: UserRole[] = [
  UserRole.complectator,
  UserRole.admin,
];

export function isSupportDutyRole(
  role: UserRole | string | null | undefined,
): boolean {
  return (
    role === UserRole.complectator || role === UserRole.admin
  );
}

export function hasSupportDutyRole(roles: UserRole[]): boolean {
  return roles.some((role) => isSupportDutyRole(role));
}

/** Roles that may be assigned via Artur elevate (not self-serve). */
export const ASSIGNABLE_ROLES: UserRole[] = [
  UserRole.client,
  UserRole.designer,
  UserRole.complectator,
  UserRole.surveyor,
  UserRole.admin,
];
