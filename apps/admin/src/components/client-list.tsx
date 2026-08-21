'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { clientLabel } from '@/lib/format';
import type { ClientScope, ClientSummary } from '@/lib/types';

const SCOPES: Array<{ id: ClientScope; label: string }> = [
  { id: 'all', label: 'Все' },
  { id: 'projects', label: 'С проектами' },
  { id: 'orders', label: 'С заказами' },
  { id: 'mine', label: 'Мои' },
];

export function ClientList({ selectedId }: { selectedId?: string }) {
  const [scope, setScope] = useState<ClientScope>('all');
  const [query, setQuery] = useState('');
  const [items, setItems] = useState<ClientSummary[]>([]);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const handle = setTimeout(() => {
      const params = new URLSearchParams({
        limit: '80',
        scope,
      });
      if (query.trim()) params.set('q', query.trim());
      api<{ items: ClientSummary[]; total: number }>(
        `/staff/clients?${params.toString()}`,
      )
        .then((page) => {
          setItems(page.items);
          setTotal(page.total);
          setError(null);
        })
        .catch((err: Error) => setError(err.message));
    }, 200);
    return () => clearTimeout(handle);
  }, [scope, query]);

  return (
    <aside className="flex h-full w-[380px] shrink-0 flex-col bg-[var(--panel)]">
      <div className="border-b border-[var(--rule)] px-4 py-4">
        <p className="text-xs tracking-[0.14em] text-[var(--muted)] uppercase">
          Клиенты · {total}
        </p>
        <div className="mt-3 flex flex-wrap gap-1">
          {SCOPES.map((item) => (
            <button
              key={item.id}
              onClick={() => setScope(item.id)}
              className={`px-2 py-1 text-xs ${
                scope === item.id
                  ? 'bg-[var(--ink)] text-[var(--paper)]'
                  : 'border border-[var(--rule)]'
              }`}
            >
              {item.label}
            </button>
          ))}
        </div>
        <input
          className="mt-3 w-full border border-[var(--rule)] bg-[var(--paper)] px-3 py-2 text-sm"
          placeholder="Имя или телефон"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
      </div>
      <div className="flex-1 overflow-y-auto">
        {error && (
          <p className="px-4 py-3 text-sm text-[var(--alert)]">{error}</p>
        )}
        {items.map((client) => {
          const active = client.id === selectedId;
          return (
            <Link
              key={client.id}
              href={`/clients/${client.id}`}
              className={`block border-b border-[var(--rule)] px-4 py-3 ${
                active ? 'bg-[var(--copper-ink)]' : 'hover:bg-[var(--paper)]'
              }`}
            >
              <div className="flex items-baseline justify-between gap-2">
                <span className="font-medium">{clientLabel(client)}</span>
                <span className="font-[family-name:var(--font-plex-mono)] text-xs text-[var(--muted)]">
                  {client.phone}
                </span>
              </div>
              <p className="mt-1 text-xs text-[var(--muted)]">
                {client.projectsCount} проект. · {client.ordersCount} зак.
              </p>
            </Link>
          );
        })}
        {items.length === 0 && !error && (
          <p className="px-4 py-8 text-sm text-[var(--muted)]">
            Никого не нашли
          </p>
        )}
      </div>
    </aside>
  );
}
