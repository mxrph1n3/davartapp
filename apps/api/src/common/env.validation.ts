const WEAK_JWT_PATTERN = /change-me|^test-secret$|^secret$|^password$/i;

/**
 * Fail fast on missing/weak secrets before the app accepts traffic.
 * Non-production allows shorter secrets for local + e2e.
 */
export function validateEnvironment(
  env: NodeJS.ProcessEnv = process.env,
): void {
  const nodeEnv = env.NODE_ENV ?? 'development';
  const jwtSecret = env.JWT_SECRET?.trim();

  if (!jwtSecret || jwtSecret.length < 8) {
    throw new Error('JWT_SECRET is required (min 8 characters)');
  }

  if (nodeEnv === 'production') {
    if (jwtSecret.length < 32) {
      throw new Error(
        'JWT_SECRET must be at least 32 characters in production',
      );
    }
    if (WEAK_JWT_PATTERN.test(jwtSecret)) {
      throw new Error(
        'JWT_SECRET looks like a placeholder — set a strong random value in production',
      );
    }
    if (!env.CORS_ORIGIN?.trim()) {
      throw new Error('CORS_ORIGIN is required in production');
    }
    if (!env.REDIS_URL?.trim()) {
      throw new Error('REDIS_URL is required in production');
    }
    if (env.ALLOW_DEV_ENDPOINTS === 'true') {
      throw new Error('ALLOW_DEV_ENDPOINTS must not be enabled in production');
    }
  }
}

export function resolveCorsOrigins(
  env: NodeJS.ProcessEnv = process.env,
): string[] | boolean {
  const raw = env.CORS_ORIGIN?.trim();
  if (raw) {
    return raw
      .split(',')
      .map((origin) => origin.trim())
      .filter(Boolean);
  }
  // Browser CORS is irrelevant for Flutter; keep permissive only outside prod.
  return env.NODE_ENV === 'production' ? false : true;
}
