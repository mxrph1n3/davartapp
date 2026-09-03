import { ForbiddenException } from '@nestjs/common';

/**
 * Internal/admin mutations (order status, start-work).
 * Requires ADMIN_API_SECRET and matching `x-admin-secret` header.
 */
export function assertAdminAccess(adminSecretHeader?: string | string[]): void {
  const expected = process.env.ADMIN_API_SECRET;
  if (!expected) {
    throw new ForbiddenException('Admin endpoints are disabled');
  }

  const provided = Array.isArray(adminSecretHeader)
    ? adminSecretHeader[0]
    : adminSecretHeader;

  if (!provided || provided !== expected) {
    throw new ForbiddenException('Invalid admin credentials');
  }
}
