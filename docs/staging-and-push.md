# Staging, push и работа из России без VPN

Чат **не зависит от Google**. Сообщения, голос и файлы идут на ваш API + MinIO + WebSocket. Если сервер в РФ (или в дружественной юрисдикции) и домен резолвится — **VPN не нужен**.

Firebase / FCM в России часто недоступны. Их **не используем как обязательный канал**. Push на заблокированном экране — отдельный слой (RuStore / свой APNs), не основа мессенджера.

## Что уже лежит в репозитории

| Файл | Зачем |
|------|--------|
| `apps/api/Dockerfile` | сборка Nest API |
| `infra/docker-compose.staging.yml` | Postgres, Redis, Meili, MinIO, API |
| `infra/.env.staging.example` | секреты staging |
| `infra/nginx.staging.conf.example` | HTTPS + WebSocket `/ws` |
| `firebase_*` | **опционально**, только если FCM доступен; без конфигов приложение живёт на mock |

## Каналы доставки (по приоритету для РФ)

| Канал | VPN | Когда работает |
|--------|-----|----------------|
| HTTP API + MinIO | нет | всегда, если хостинг в РФ / доступен |
| Socket.io `/ws` | нет | приложение открыто |
| SMS.ru (OTP) | нет | ключ в env |
| RuStore Push (Android) | нет | публикация в RuStore, следующий этап |
| Apple APNs напрямую | нет* | свой ключ `.p8`, без Firebase |
| Firebase / FCM | часто да | не опираться |

\* APNs с сервера в РФ обычно доступен; Google FCM — нет.

Пока нет RuStore/APNs: новые сообщения в фоне видны после открытия чата (сокет + pull). Это нормальный MVP для России.

## 1. Что купить / завести (минимум)

1. **VPS в России** (Timeweb, Selectel, REG.RU, Yandex Cloud) — 2 GB RAM+. Не Hetzner/DO, если цель «точно без VPN».
2. **Домен .ru** — `api.` и при необходимости `files.` (A-запись на IP VPS). Let's Encrypt работает.
3. SMS.ru — OTP без Google.
4. Push на экране блокировки — **после** живого API; не блокирует чат.

## 2. Staging на VPS

На сервере:

```bash
git clone <repo> && cd davartapp
cp infra/.env.staging.example infra/.env.staging
# JWT_SECRET, POSTGRES_PASSWORD, CORS_ORIGIN, S3_PUBLIC_BASE_URL=https://files.…
nano infra/.env.staging

docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging up -d --build
curl http://127.0.0.1:3000/api/health
```

Nginx + certbot: `infra/nginx.staging.conf.example`.  
Обязательно проксировать **WebSocket** (`Upgrade`).

Файлы: публичный `https://files.ваш-домен.ru` на MinIO, не `localhost` и не зарубежный S3, если цель — без VPN.

Seed:

```bash
docker compose -f infra/docker-compose.staging.yml exec api npx prisma db seed
```

## 3. Приложение

```bash
cd apps/mobile
flutter run --dart-define=API_BASE_URL=https://api.ваш-домен.ru/api
```

Проверка без VPN: Wi‑Fi/LTE в РФ, вход, текст + голосовое второму аккаунту.

## 4. Push (не Firebase)

Не подключайте Firebase как основной путь для продакшена в РФ.

**Сейчас:** mock-токен, в логе API `[PUSH MOCK]`. Чат от этого не ломается.

**Дальше (когда будет магазин):**
- Android: [RuStore Push](https://www.rustore.ru/help/developers/developer-tools/rustore-push-sdk) — токен на API вместо FCM.
- iOS: APNs HTTP/2 с ключом из Apple Developer, без Google.
- Поле `fcm_tokens` можно переименовать в `device_tokens` + `provider: rustore | apns | fcm`.

`FCM_SERVER_KEY` в env **не обязателен**.

## 5. Чеклист «работает в России»

- [ ] API и MinIO на РФ-хостинге, HTTPS
- [ ] DNS .ru резолвится с МТС/Мегафон/Теле2 без VPN
- [ ] OTP через SMS.ru, не Firebase Auth
- [ ] В приложении нет обязательного вызова Google при старте (сейчас Firebase init в try/catch — ок)
- [ ] Каталожные картинки с вашего `S3_PUBLIC_BASE_URL`, не unsplash/googleusercontent
- [ ] WebSocket не режется провайдером (wss на 443)

## 6. Ещё не сделано

- RuStore Push SDK
- Прямой APNs с API
- Автодеплой
- Production SMS
