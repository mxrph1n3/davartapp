'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { api, clearTokens, getAccessToken } from '@/lib/api';
import type { SessionUser } from '@/lib/types';

const STUDIO = new Set(['designer', 'complectator', 'admin']);

export function AuthGate({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const [user, setUser] = useState<SessionUser | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!getAccessToken()) {
      router.replace('/login');
      return;
    }
    api<SessionUser>('/users/me')
      .then((me) => {
        if (!STUDIO.has(me.role)) {
          clearTokens();
          router.replace('/login');
          return;
        }
        setUser(me);
        setReady(true);
      })
      .catch(() => router.replace('/login'));
  }, [router]);

  if (!ready || !user) {
    return (
      <div className="flex min-h-screen items-center justify-center text-sm text-[var(--muted)]">
        Открываем кабинет…
      </div>
    );
  }

  return (
    <div className="flex h-dvh min-h-screen flex-col">
      <header className="flex shrink-0 items-center justify-between border-b border-[var(--rule)] px-5 py-3">
        <div>
          <p className="font-[family-name:var(--font-fraunces)] text-xl leading-none">
            Davart
          </p>
          <p className="mt-1 text-xs tracking-[0.16em] text-[var(--muted)] uppercase">
            CRM комплектации
          </p>
        </div>
        <div className="flex items-center gap-4 text-sm">
          <span className="text-[var(--muted)]">
            {user.name?.trim() || user.phone}
          </span>
          <button
            className="text-[var(--copper)]"
            onClick={() => {
              clearTokens();
              router.replace('/login');
            }}
          >
            Выйти
          </button>
        </div>
      </header>
      <div className="flex min-h-0 flex-1">{children}</div>
    </div>
  );
}
