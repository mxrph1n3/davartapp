import { UserRole } from '@prisma/client';

/** Field / CRM roles that use the studio (staff) shell and /staff APIs. */
export const STUDIO_ROLES: UserRole[] = [
  UserRole.designer,
  UserRole.complectator,
  UserRole.admin,
];

export function isStudioRole(role: UserRole | string | null | undefined): boolean {
  return (
    role === UserRole.designer ||
    role === UserRole.complectator ||
    role === UserRole.admin
  );
}

export function isAdminRole(role: UserRole | string | null | undefined): boolean {
  return role === UserRole.admin;
}

/** Client phones in chats: manager (complectator) and admin only. */
export function canSeeContactPhone(
  role: UserRole | string | null | undefined,
): boolean {
  return role === UserRole.complectator || role === UserRole.admin;
}

/** Roles that may be assigned via Artur elevate (not self-serve). */
export const ASSIGNABLE_ROLES: UserRole[] = [
  UserRole.client,
  UserRole.designer,
  UserRole.complectator,
  UserRole.admin,
];
