'use client';

import { usePathname } from 'next/navigation';
import type { ReactNode } from 'react';
import { AuthGate } from '@/components/auth-gate';
import { ClientList } from '@/components/client-list';

export default function ClientsLayout({ children }: { children: ReactNode }) {
  return (
    <AuthGate>
      <ClientsSplit>{children}</ClientsSplit>
    </AuthGate>
  );
}

function ClientsSplit({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const selectedId = pathname.match(/^\/clients\/([^/]+)/)?.[1];

  return (
    <div className="flex min-h-0 flex-1">
      <ClientList selectedId={selectedId} />
      <div className="master-rule shrink-0" aria-hidden />
      <div className="flex min-w-0 flex-1 flex-col bg-[var(--paper)]">
        {children}
      </div>
    </div>
  );
}
