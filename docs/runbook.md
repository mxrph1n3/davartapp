# Runbook — Davart App

## Контакты

| Роль | Канал |
|------|-------|
| On-call | @devops в Slack |
| Поддержка клиентов | support@davart.ru |

## Сервисы production

| Сервис | URL | Health |
|--------|-----|--------|
| API | `https://api.davart.ru/api/health` | 200 + `status: ok` |
| CRM | `https://crm.davart.ru` | OTP login → список клиентов |
| MinIO | internal | bucket `davart` |
| PostgreSQL | internal | `$queryRaw` в health |
| Redis | internal | ping |
| Meilisearch | internal | `/health` |

## Типовые инциденты

### API не отвечает (5xx)

1. Проверить `GET /api/health`
2. Проверить логи контейнера API (`kubectl logs` / Docker)
3. Проверить PostgreSQL и Redis
4. Rollback на предыдущий образ при деплое

### OTP не приходит

1. Проверить `SMS_PROVIDER` и баланс SMS.ru
2. Проверить rate limit в Redis (`otp:*` keys)
3. В dev: `SMS_PROVIDER=mock`, код в логах API

### Поиск не работает

1. `GET /api/health` → `meilisearch`
2. `POST /api/catalog/reindex` (dev/staging)
3. Проверить `MEILISEARCH_HOST` и API key

### Push не доставляются

1. Проверить `FCM_SERVER_KEY` в env
2. Без ключа — mock-режим (логи `[PUSH MOCK]`)
3. Проверить `notificationsEnabled` у пользователя
4. Проверить наличие FCM-токена в `fcm_tokens`

### WebSocket / чат

1. Проверить path `/ws` и JWT в query `?token=`
2. Проверить sticky sessions при нескольких репликах API
3. Redis adapter для Socket.IO при горизонтальном масштабировании

## Деплой

```bash
# API
cd apps/api
npm ci
npx prisma migrate deploy
npm run build
npm run start:prod

# CRM (Next standalone, порт 3001)
cd apps/admin
npm ci && npm run build
# nginx + systemd: apps/admin/DEPLOY.md

# Mobile beta
cd apps/mobile
flutter build ipa --release    # iOS → TestFlight
flutter build appbundle        # Android → Play Console
```

## Мониторинг

- **Sentry**: ошибки API (env `SENTRY_DSN`)
- **Uptime**: ping `/api/health` каждые 60 сек
- **Алерты**: 5xx rate > 1%, health down > 2 min

## Эскалация

1. P0 (auth down, data loss) — немедленно, rollback
2. P1 (orders/chat broken) — в течение 1 часа
3. P2 (UI bugs) — следующий спринт / hotfix
