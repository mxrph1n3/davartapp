'use client';

import { FormEvent, useEffect, useMemo, useState } from 'react';
import { api } from '@/lib/api';
import { clientLabel, formatDate, formatDateTime, formatMoney } from '@/lib/format';
import type {
  Address,
  AuditEntry,
  Cart,
  ClientProfile,
  DocumentItem,
  Order,
  Project,
} from '@/lib/types';

const TABS = [
  { id: 'projects', label: 'Проекты' },
  { id: 'documents', label: 'Документы' },
  { id: 'cart', label: 'Корзина' },
  { id: 'history', label: 'История' },
  { id: 'profile', label: 'Профиль' },
] as const;

type TabId = (typeof TABS)[number]['id'];

export function ClientDetail({
  clientId,
  highlightOrderId,
}: {
  clientId: string;
  highlightOrderId?: string;
}) {
  const [tab, setTab] = useState<TabId>(highlightOrderId ? 'history' : 'projects');
  const [client, setClient] = useState<ClientProfile | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api<ClientProfile>(`/staff/clients/${clientId}`)
      .then(setClient)
      .catch((err: Error) => setError(err.message));
  }, [clientId]);

  useEffect(() => {
    if (highlightOrderId) setTab('history');
  }, [highlightOrderId]);

  if (error) {
    return <p className="p-8 text-[var(--alert)]">{error}</p>;
  }
  if (!client) {
    return <p className="p-8 text-[var(--muted)]">Загружаем карточку…</p>;
  }

  return (
    <section className="flex min-h-0 flex-1 flex-col">
      <header className="border-b border-[var(--rule)] px-6 py-5">
        <h1 className="font-[family-name:var(--font-fraunces)] text-3xl">
          {clientLabel(client)}
        </h1>
        <p className="mt-1 font-[family-name:var(--font-plex-mono)] text-sm text-[var(--muted)]">
          {client.phone}
          {client.email ? ` · ${client.email}` : ''}
        </p>
        <p className="mt-2 text-sm text-[var(--muted)]">
          {client.projectsCount} проектов · {client.ordersCount} заказов ·{' '}
          {client.cartItemsCount} позиций в корзинах
        </p>
      </header>
      <nav className="flex gap-1 border-b border-[var(--rule)] px-4">
        {TABS.map((item) => (
          <button
            key={item.id}
            onClick={() => setTab(item.id)}
            className={`px-3 py-3 text-sm ${
              tab === item.id
                ? 'border-b-2 border-[var(--copper)] font-medium'
                : 'text-[var(--muted)]'
            }`}
          >
            {item.label}
          </button>
        ))}
      </nav>
      <div className="min-h-0 flex-1 overflow-y-auto p-6">
        {tab === 'projects' && <ProjectsTab clientId={clientId} />}
        {tab === 'documents' && <DocumentsTab clientId={clientId} />}
        {tab === 'cart' && <CartTab clientId={clientId} />}
        {tab === 'history' && (
          <HistoryTab clientId={clientId} highlightOrderId={highlightOrderId} />
        )}
        {tab === 'profile' && (
          <ProfileTab client={client} onSaved={setClient} />
        )}
      </div>
    </section>
  );
}

function ProjectsTab({ clientId }: { clientId: string }) {
  const [projects, setProjects] = useState<Project[]>([]);
  useEffect(() => {
    api<Project[]>(`/staff/clients/${clientId}/projects`).then(setProjects);
  }, [clientId]);

  if (projects.length === 0) {
    return <p className="text-sm text-[var(--muted)]">Проектов пока нет</p>;
  }

  return (
    <ul className="divide-y divide-[var(--rule)] border border-[var(--rule)]">
      {projects.map((project) => (
        <li key={project.id} className="px-4 py-3">
          <p className="font-medium">{project.name}</p>
          <p className="text-sm text-[var(--muted)]">
            {project.statusLabel ?? project.status}
            {project.address ? ` · ${project.address}` : ''}
          </p>
        </li>
      ))}
    </ul>
  );
}

function DocumentsTab({ clientId }: { clientId: string }) {
  const [docs, setDocs] = useState<DocumentItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);
    api<Project[]>(`/staff/clients/${clientId}/projects`)
      .then(async (projects) => {
        const lists = await Promise.all(
          projects.map((project) =>
            api<DocumentItem[]>(`/projects/${project.id}/documents`).catch(
              () => [] as DocumentItem[],
            ),
          ),
        );
        setDocs(lists.flat());
      })
      .finally(() => setLoading(false));
  }, [clientId]);

  if (loading) return <p className="text-sm text-[var(--muted)]">Документы…</p>;
  if (docs.length === 0) {
    return <p className="text-sm text-[var(--muted)]">Файлов пока нет</p>;
  }

  return (
    <ul className="divide-y divide-[var(--rule)] border border-[var(--rule)]">
      {docs.map((doc) => (
        <li key={doc.id} className="flex items-center justify-between px-4 py-3">
          <div>
            <p className="font-medium">{doc.name}</p>
            <p className="text-xs text-[var(--muted)]">
              {doc.typeLabel} · {formatDateTime(doc.uploadedAt)}
            </p>
          </div>
          <DownloadLink id={doc.id} />
        </li>
      ))}
    </ul>
  );
}

function DownloadLink({ id }: { id: string }) {
  const [busy, setBusy] = useState(false);
  return (
    <button
      className="text-sm text-[var(--copper)]"
      disabled={busy}
      onClick={async () => {
        setBusy(true);
        try {
          const result = await api<{ url: string }>(`/documents/${id}/download`);
          window.open(result.url, '_blank');
        } finally {
          setBusy(false);
        }
      }}
    >
      Скачать
    </button>
  );
}

function CartTab({ clientId }: { clientId: string }) {
  const [projects, setProjects] = useState<Project[]>([]);
  const [projectId, setProjectId] = useState<string>('');
  const [cart, setCart] = useState<Cart | null>(null);

  useEffect(() => {
    api<Project[]>(`/staff/clients/${clientId}/projects`).then((list) => {
      setProjects(list);
      if (list[0]) setProjectId(list[0].id);
    });
  }, [clientId]);

  useEffect(() => {
    if (!projectId) return;
    api<Cart>(`/staff/projects/${projectId}/cart`).then(setCart);
  }, [projectId]);

  if (projects.length === 0) {
    return <p className="text-sm text-[var(--muted)]">Нет проекта — нет корзины</p>;
  }

  return (
    <div>
      <select
        className="mb-4 border border-[var(--rule)] bg-[var(--panel)] px-3 py-2 text-sm"
        value={projectId}
        onChange={(e) => setProjectId(e.target.value)}
      >
        {projects.map((project) => (
          <option key={project.id} value={project.id}>
            {project.name}
          </option>
        ))}
      </select>
      {!cart || cart.items.length === 0 ? (
        <p className="text-sm text-[var(--muted)]">Корзина пуста</p>
      ) : (
        <table className="w-full text-sm">
          <thead className="text-left text-[var(--muted)]">
            <tr>
              <th className="py-2 font-medium">Позиция</th>
              <th className="py-2 font-medium">Кол-во</th>
              <th className="py-2 font-medium">Цена</th>
            </tr>
          </thead>
          <tbody>
            {cart.items.map((item) => (
              <tr key={item.id} className="border-t border-[var(--rule)]">
                <td className="py-2">
                  {item.product.name}
                  <span className="ml-2 font-[family-name:var(--font-plex-mono)] text-xs text-[var(--muted)]">
                    {item.product.sku}
                  </span>
                </td>
                <td className="py-2">{item.quantity}</td>
                <td className="py-2">{formatMoney(item.product.price)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}

function HistoryTab({
  clientId,
  highlightOrderId,
}: {
  clientId: string;
  highlightOrderId?: string;
}) {
  const [orders, setOrders] = useState<Order[]>([]);
  const [audit, setAudit] = useState<AuditEntry[]>([]);

  useEffect(() => {
    api<Order[] | { items: Order[] }>(`/staff/clients/${clientId}/orders`).then(
      (data) => setOrders(Array.isArray(data) ? data : data.items ?? []),
    );
    api<{ items: AuditEntry[] }>(
      `/staff/audit?clientId=${clientId}&limit=40`,
    ).then((page) => setAudit(page.items));
  }, [clientId]);

  const highlighted = useMemo(
    () => orders.find((order) => order.id === highlightOrderId),
    [orders, highlightOrderId],
  );

  return (
    <div className="grid gap-8 lg:grid-cols-2">
      <div>
        <h2 className="mb-3 text-sm tracking-[0.12em] text-[var(--muted)] uppercase">
          Заказы
        </h2>
        {highlighted && (
          <p className="mb-3 border border-[var(--copper)] bg-[var(--copper-ink)] px-3 py-2 text-sm">
            Открыт из Telegram: {formatMoney(highlighted.totalAmount)} ·{' '}
            {highlighted.statusLabel ?? highlighted.status}
          </p>
        )}
        {orders.length === 0 ? (
          <p className="text-sm text-[var(--muted)]">Заказов нет</p>
        ) : (
          <ul className="divide-y divide-[var(--rule)] border border-[var(--rule)]">
            {orders.map((order) => (
              <li
                key={order.id}
                className={`px-4 py-3 ${
                  order.id === highlightOrderId ? 'bg-[var(--copper-ink)]' : ''
                }`}
              >
                <p className="font-medium">
                  {formatMoney(order.totalAmount)} ·{' '}
                  {order.statusLabel ?? order.status}
                </p>
                <p className="text-xs text-[var(--muted)]">
                  {formatDateTime(order.createdAt)} · {order.address}
                </p>
              </li>
            ))}
          </ul>
        )}
      </div>
      <div>
        <h2 className="mb-3 text-sm tracking-[0.12em] text-[var(--muted)] uppercase">
          Активность
        </h2>
        {audit.length === 0 ? (
          <p className="text-sm text-[var(--muted)]">Пока тихо</p>
        ) : (
          <ul className="space-y-3 text-sm">
            {audit.map((entry) => (
              <li key={entry.id}>
                <p>{entry.actionLabel}</p>
                <p className="text-xs text-[var(--muted)]">
                  {entry.actor.name} · {formatDateTime(entry.createdAt)}
                </p>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}

function ProfileTab({
  client,
  onSaved,
}: {
  client: ClientProfile;
  onSaved: (client: ClientProfile) => void;
}) {
  const [name, setName] = useState(client.name ?? '');
  const [email, setEmail] = useState(client.email ?? '');
  const [birthDate, setBirthDate] = useState(
    client.birthDate ? client.birthDate.slice(0, 10) : '',
  );
  const [addresses, setAddresses] = useState<Address[]>([]);
  const [message, setMessage] = useState<string | null>(null);

  useEffect(() => {
    api<Address[]>(`/staff/clients/${client.id}/addresses`).then(setAddresses);
  }, [client.id]);

  async function save(event: FormEvent) {
    event.preventDefault();
    const updated = await api<ClientProfile>(`/staff/clients/${client.id}`, {
      method: 'PATCH',
      body: JSON.stringify({
        name: name.trim() || undefined,
        email: email.trim() || undefined,
        birthDate: birthDate || undefined,
      }),
    });
    onSaved(updated);
    setMessage('Сохранено');
  }

  return (
    <div className="max-w-xl space-y-8">
      <form onSubmit={save} className="space-y-3">
        <Field label="Имя" value={name} onChange={setName} />
        <label className="block text-sm text-[var(--muted)]">
          Телефон
          <input
            disabled
            value={client.phone}
            className="mt-1 w-full border border-[var(--rule)] bg-[var(--paper)] px-3 py-2 font-[family-name:var(--font-plex-mono)] text-sm"
          />
        </label>
        <Field label="Email" value={email} onChange={setEmail} />
        <label className="block text-sm text-[var(--muted)]">
          День рождения
          <input
            type="date"
            value={birthDate}
            onChange={(e) => setBirthDate(e.target.value)}
            className="mt-1 w-full border border-[var(--rule)] bg-[var(--panel)] px-3 py-2 text-sm"
          />
        </label>
        <p className="text-xs text-[var(--muted)]">
          Клиент с {formatDate(client.createdAt)}
        </p>
        <button className="bg-[var(--ink)] px-4 py-2 text-sm text-[var(--paper)]">
          Сохранить
        </button>
        {message && <span className="ml-3 text-sm text-[var(--copper)]">{message}</span>}
      </form>
      <div>
        <h2 className="mb-3 text-sm tracking-[0.12em] text-[var(--muted)] uppercase">
          Адреса
        </h2>
        {addresses.length === 0 ? (
          <p className="text-sm text-[var(--muted)]">Адресов нет</p>
        ) : (
          <ul className="space-y-2 text-sm">
            {addresses.map((address) => (
              <li key={address.id} className="border border-[var(--rule)] px-3 py-2">
                {address.city}, {address.street}, {address.building}
                {address.apartment ? `, кв. ${address.apartment}` : ''}
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}

function Field({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <label className="block text-sm text-[var(--muted)]">
      {label}
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="mt-1 w-full border border-[var(--rule)] bg-[var(--panel)] px-3 py-2 text-sm text-[var(--ink)]"
      />
    </label>
  );
}
