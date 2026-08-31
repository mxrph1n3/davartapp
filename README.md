# Davart App

Мобильное приложение интерьерной дизайн-студии: каталог, проекты, чат.

**Стек:** Flutter · NestJS · Next.js CRM · PostgreSQL · Redis · Meilisearch · MinIO

## Документация

- [PLAN.md](./PLAN.md) — план v2.0: экосистема Mobile + CRM, спринты 0–13 ✅, roadmap 14–21 (§18)
- [docs/adr/](./docs/adr/) — архитектурные решения
- [docs/runbook.md](./docs/runbook.md) — эксплуатация и инциденты
- [docs/chat-setup.md](./docs/chat-setup.md) — чат, медиа, MinIO, голосовые
- [docs/staging-and-push.md](./docs/staging-and-push.md) — staging в РФ, чат без VPN, push без Firebase
- [docs/release/beta-guide.md](./docs/release/beta-guide.md) — TestFlight / Play Internal
- [docs/legal/](./docs/legal/) — Privacy Policy, Terms of Service

## Требования

- Node.js 22+
- Flutter 3.x
- Docker CLI + **Colima** (macOS) или Docker Desktop

На macOS одного `brew install docker` недостаточно — нужен runtime:

```bash
brew install colima docker docker-compose
colima start
```

## Быстрый старт (локально)

Открывайте **три терминала**. Команды — из корня репозитория или с абсолютными путями.

### 1. Инфраструктура

```bash
colima start                          # если ещё не запущен
cd /Users/sadism/Documents/davartapp/infra
cp -n .env.example .env
docker-compose up -d                  # или: docker compose up -d
docker ps                             # postgres/redis/meili/minio = healthy
```

| Сервис | Порт |
|--------|------|
| PostgreSQL | 5432 |
| Redis | 6379 |
| Meilisearch | 7700 |
| MinIO | 9000 / 9001 |

### 2. Backend (API)

```bash
cd /Users/sadism/Documents/davartapp/apps/api
cp -n .env.example .env
npm install
npx prisma migrate deploy
npx prisma db seed
# or refresh images only (keeps carts/orders): npm run prisma:refresh-images
npm run start:dev
```

Каталог: тематические фото в MinIO (`http://localhost:9000/davart/catalog/…`). Публичная база: `S3_PUBLIC_BASE_URL` в `.env`.

API: http://localhost:3000/api  

OTP в режиме mock пишется в этот терминал:

```text
[MOCK SMS] OTP for +79001234567: 1234
```

### 3. Mobile (iOS Simulator)

```bash
cd /Users/sadism/Documents/davartapp/apps/mobile
flutter pub get
flutter run -d "iPhone 17 Pro"
```

Вход (OTP из лога API `[MOCK SMS]`):

| Роль | Телефон |
|------|---------|
| Клиент | `+79001234567` |
| Дизайнер | `+79009999999` |
| Комплектатор | `+79009999998` / `997` |
| Admin (бог) | `+79009999990` |

### 4. CRM Web (комплектатор)

```bash
cd /Users/sadism/Documents/davartapp/apps/admin
cp -n .env.local.example .env.local
npm install
npm run dev
```

http://localhost:3001 — OTP комплектатора `+79009999998`, код в логе API.  
Деплой-заготовка: [apps/admin/DEPLOY.md](./apps/admin/DEPLOY.md).

### 5. Физический iPhone (одна команда → VPS API)

```bash
cd ~/davartapp && git pull origin main && bash scripts/run-ios-device.sh
```

Скрипт: выключает SPM, `flutter clean` → `pub get` → сброс Pods → `pod install --repo-update` → ставит на телефон с API `http://217.198.6.88:3000/api`.

Через Xcode (⌘R):

```bash
cd ~/davartapp && git pull origin main && bash scripts/run-ios-device.sh --xcode
```

Первый раз (если репо ещё нет):

```bash
git clone https://github.com/mxrph1n3/davartapp.git ~/davartapp && cd ~/davartapp && bash scripts/run-ios-device.sh
```

Нужны: Flutter, Xcode, CocoaPods, iPhone по USB, Developer Mode, Team в Signing.

Release / TestFlight: см. [docs/release/beta-guide.md](./docs/release/beta-guide.md).

## Структура

```
apps/
├── mobile/    # Flutter (iOS / Android)
├── api/       # NestJS backend
└── admin/     # Next.js CRM (Master-Detail)
infra/         # Docker Compose
docs/          # ADR, runbook, legal
packages/      # Shared types
```

## Нижняя навигация

Каталог · Проекты · Чат · Корзина · Профиль

## Текущий спринт

**Sprint 0–20** ✅ · далее [PLAN §18](./PLAN.md) Sprint 21 (интеграции)

Осталось к релизу store: accounts + SMS/FCM/staging ([beta-guide](./docs/release/beta-guide.md)).

### E2E / load / legal

```bash
cd apps/api && npm run test:e2e

k6 run scripts/load/catalog.k6.js
k6 run scripts/load/chat-ws.k6.js

curl http://localhost:3000/api/legal/privacy
curl http://localhost:3000/api/legal/terms
```

### Catalog reindex

```bash
cd apps/api
npx prisma db seed
curl -X POST http://localhost:3000/api/catalog/reindex
```

### Auth smoke

```bash
curl -X POST http://localhost:3000/api/auth/send-otp \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+79001234567"}'
# код — в логе API (SMS_PROVIDER=mock)
```
