export function formatMoney(value: number): string {
  if (value <= 0) return 'по запросу';
  return `${Math.round(value).toLocaleString('ru-RU')} ₽`;
}

export function formatDate(value: string | null | undefined): string {
  if (!value) return '—';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleDateString('ru-RU');
}

export function formatDateTime(value: string | null | undefined): string {
  if (!value) return '—';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleString('ru-RU', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function clientLabel(client: {
  name: string | null;
  phone: string;
}): string {
  return client.name?.trim() || client.phone;
}
