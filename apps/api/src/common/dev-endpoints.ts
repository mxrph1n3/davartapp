import { ForbiddenException } from '@nestjs/common';

/** Dev-only endpoints (seed, reindex). Default deny unless explicitly enabled. */
export function assertDevEndpointsAllowed(): void {
  if (process.env.ALLOW_DEV_ENDPOINTS !== 'true') {
    throw new ForbiddenException('Dev endpoints are disabled');
  }
}
