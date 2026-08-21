const API_URL =
  process.env.NEXT_PUBLIC_API_URL?.replace(/\/$/, '') || '/api';

const ACCESS_KEY = 'davart.crm.access';
const REFRESH_KEY = 'davart.crm.refresh';

export function getAccessToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem(ACCESS_KEY);
}

export function setTokens(access: string, refresh: string) {
  localStorage.setItem(ACCESS_KEY, access);
  localStorage.setItem(REFRESH_KEY, refresh);
}

export function clearTokens() {
  localStorage.removeItem(ACCESS_KEY);
  localStorage.removeItem(REFRESH_KEY);
}

async function refreshAccess(): Promise<string | null> {
  const refreshToken = localStorage.getItem(REFRESH_KEY);
  if (!refreshToken) return null;
  const response = await fetch(`${API_URL}/auth/refresh`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refreshToken }),
  });
  if (!response.ok) {
    clearTokens();
    return null;
  }
  const data = (await response.json()) as {
    accessToken: string;
    refreshToken: string;
  };
  setTokens(data.accessToken, data.refreshToken);
  return data.accessToken;
}

function isNetworkError(err: unknown): boolean {
  if (err instanceof TypeError) return true;
  if (!(err instanceof Error)) return false;
  return /load failed|failed to fetch|networkerror|fetch failed/i.test(
    err.message,
  );
}

function errorMessage(text: string, status: number): string {
  try {
    const json = JSON.parse(text) as { message?: string | string[] };
    const msg = json.message;
    if (Array.isArray(msg) && msg.length) return msg.join('. ');
    if (typeof msg === 'string' && msg.trim()) return msg;
  } catch {
    /* raw body */
  }
  return text || `Ошибка ${status}`;
}

export async function api<T>(
  path: string,
  init: RequestInit = {},
  retried = false,
): Promise<T> {
  const token = getAccessToken();
  const headers = new Headers(init.headers);
  if (!headers.has('Content-Type') && init.body) {
    headers.set('Content-Type', 'application/json');
  }
  if (token) headers.set('Authorization', `Bearer ${token}`);

  let response: Response;
  try {
    response = await fetch(`${API_URL}${path}`, { ...init, headers });
  } catch (err) {
    if (isNetworkError(err)) {
      throw new Error(
        'Нет связи с API. Запустите backend: cd apps/api && npm run start:dev',
      );
    }
    throw err;
  }

  if (response.status === 401 && !retried) {
    const next = await refreshAccess();
    if (next) return api<T>(path, init, true);
    if (typeof window !== 'undefined') {
      window.location.href = '/login';
    }
    throw new Error('Нужно войти снова');
  }

  if (!response.ok) {
    const text = await response.text();
    throw new Error(errorMessage(text, response.status));
  }

  if (response.status === 204) return undefined as T;
  return (await response.json()) as T;
}
