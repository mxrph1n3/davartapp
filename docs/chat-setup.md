# Чат: медиа, голосовые, хранение

Краткая инструкция для локального запуска чата с вложениями между двумя пользователями.

## Архитектура

```
Mobile → API (NestJS) → PostgreSQL   — текст, метаданные, waveform
Mobile → MinIO (presigned URL)       — байты файлов (голос, фото, pdf)
Mobile ↔ Socket.io /ws               — новые сообщения в реальном времени
```

Без API и MinIO сообщения **не дойдут** до второго пользователя. Хостинг должен быть доступен из РФ без VPN (свой VPS + домен .ru). Google/Firebase для чата не используются.

## 1. Инфраструктура

```bash
colima start   # если ещё не запущен
cd infra
docker compose up -d
docker ps      # postgres, redis, minio = healthy
```

MinIO консоль: http://localhost:9001 (`davart` / `davartsecret`).

## 2. API

```bash
cd apps/api
cp -n .env.example .env
npm install
npx prisma migrate deploy
npx prisma db seed
npm run start:dev
```

В логе должно быть: `S3 bucket "davart" ready`.

Проверка:

```bash
curl http://localhost:3000/api/health
```

## 3. Mobile

```bash
cd apps/mobile
flutter pub get
flutter run -d "iPhone 17 Pro"
```

После добавления нативных плагинов (`record`, `just_audio`) — **полный перезапуск** (`q` → `flutter run`), не hot reload.

### Физическое устройство

```bash
ipconfig getifaddr en0
flutter run --dart-define=API_BASE_URL=http://<LAN-IP>:3000/api
```

## 4. Тестовые аккаунты

OTP в логе API: `[MOCK SMS] OTP for ...`

| Роль | Телефон |
|------|---------|
| Клиент | +79001234567 |
| Дизайнер | +79009999999 |

Откройте чат проекта с обоих аккаунтов (два симулятора или симулятор + телефон).

## 5. Что проверить

| Действие | Ожидание |
|----------|----------|
| Текст | Мгновенно у второго пользователя |
| Голос (зажать микрофон) | Пузырь с волной, play |
| Галерея / файл | Превью или карточка файла |
| MinIO выключен | Snackbar «Файловое хранилище недоступно» |
| Отправка | Пузырь «отправляется» → подтверждение |
| Ошибка сети | Пузырь с «Повторить отправку» (до 3 попыток upload) |
| Печатает | Под полем ввода — «Печатает…» |

## 6. Типы вложений (API)

- `image/jpeg`, `png`, `webp`, `heic`, `gif`
- `audio/mp4` (голос `.m4a`)
- `application/pdf`, `zip`, dwg, office
- Максимум **50 МБ**

## 7. Продакшен (кратко)

1. PostgreSQL + Redis + S3/MinIO на сервере
2. `S3_*` в `.env` API, бакет приватный
3. HTTPS + прокси `/ws` для WebSocket
4. Mobile: `--dart-define=API_BASE_URL=https://api.example.com/api`
5. Реальный SMS (`SMS_PROVIDER=smsru`)

## 8. Полезные команды

```bash
# E2E чата
cd apps/api && npm run test:e2e -- chat.e2e-spec

# Load WebSocket
k6 run scripts/load/chat-ws.k6.js
```
