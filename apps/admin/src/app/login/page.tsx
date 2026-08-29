'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';
import { api, clearTokens, setTokens } from '@/lib/api';
import { canUseCrm, type SessionUser } from '@/lib/types';

export default function LoginPage() {
  const router = useRouter();
  const [phone, setPhone] = useState('+79009999998');
  const [code, setCode] = useState('');
  const [step, setStep] = useState<'phone' | 'code'>('phone');
  const [error, setError] = useState<string | null>(null);
  const [hint, setHint] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function sendOtp(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setHint(null);
    setPending(true);
    try {
      const res = await api<{ message: string; debugCode?: string }>(
        '/auth/send-otp',
        {
          method: 'POST',
          body: JSON.stringify({ phone: phone.trim() }),
        },
      );
      setStep('code');
      if (res.debugCode) {
        setHint(`Mock-код: ${res.debugCode}`);
        setCode(res.debugCode);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Не удалось отправить код');
    } finally {
      setPending(false);
    }
  }

  async function verify(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setPending(true);
    try {
      const tokens = await api<{ accessToken: string; refreshToken: string }>(
        '/auth/verify-otp',
        {
          method: 'POST',
          body: JSON.stringify({ phone: phone.trim(), code: code.trim() }),
        },
      );
      setTokens(tokens.accessToken, tokens.refreshToken);
      const me = await api<SessionUser>('/users/me');
      if (!canUseCrm(me)) {
        clearTokens();
        setError(
          'CRM только для комплектаторов и админов. Дизайнерам — мобильное приложение.',
        );
        return;
      }
      router.replace('/clients');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Неверный код');
    } finally {
      setPending(false);
    }
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-6">
      <p className="font-[family-name:var(--font-fraunces)] text-3xl tracking-tight">
        Davart
      </p>
      <h1 className="mt-2 text-lg text-[var(--muted)]">Кабинет комплектации</h1>
      <form
        onSubmit={step === 'phone' ? sendOtp : verify}
        className="mt-10 space-y-4"
      >
        <label className="block text-sm text-[var(--muted)]">
          Телефон
          <input
            className="mt-1 w-full border border-[var(--rule)] bg-[var(--panel)] px-3 py-2 font-[family-name:var(--font-plex-mono)] text-sm"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            autoComplete="tel"
            inputMode="tel"
          />
        </label>
        {step === 'code' && (
          <label className="block text-sm text-[var(--muted)]">
            Код из SMS
            <input
              className="mt-1 w-full border border-[var(--rule)] bg-[var(--panel)] px-3 py-2 font-[family-name:var(--font-plex-mono)] text-sm tracking-[0.4em]"
              value={code}
              onChange={(e) => setCode(e.target.value)}
              autoComplete="one-time-code"
              inputMode="numeric"
              maxLength={4}
              autoFocus
            />
          </label>
        )}
        {hint && <p className="text-sm text-[var(--muted)]">{hint}</p>}
        {error && <p className="text-sm text-[var(--alert)]">{error}</p>}
        <button
          type="submit"
          disabled={pending}
          className="w-full bg-[var(--ink)] px-4 py-2.5 text-sm font-medium text-[var(--paper)] disabled:opacity-50"
        >
          {pending
            ? 'Секунду…'
            : step === 'phone'
              ? 'Получить код'
              : 'Войти'}
        </button>
      </form>
      <p className="mt-8 text-xs text-[var(--muted)]">
        Комплектатор +79009999998 · в mock код приходит в ответе API
      </p>
    </main>
  );
}
