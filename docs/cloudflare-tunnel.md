# Вариант B: домашний ПК как сервер через Cloudflare Tunnel

Порты роутера **не открываются**. Телефон ходит на Cloudflare, туннель стучится в твой Ubuntu.

Нужен аккаунт [Cloudflare](https://dash.cloudflare.com) и домен (можно `.ru`, NS делегировать на Cloudflare).

## 1. Туннель в кабинете

1. [Zero Trust](https://one.dash.cloudflare.com) → **Networks** → **Tunnels** → **Create**.
2. Имя: `davart-home`.
3. Тип: **Cloudflared** → **Docker**.
4. Скопируй команду — из неё нужен только **токен** после `--token`.

## 2. Публичные имена (в том же туннеле)

| Public hostname | Type | URL (важно: имена сервисов Docker) |
|-----------------|------|--------------------------------------|
| `api.твой-домен.ru` | HTTP | `http://api:3000` |
| `files.твой-домен.ru` | HTTP | `http://minio:9000` |

Не пиши `localhost` и не пиши `192.168.x` — cloudflared крутится **внутри Docker**.

Сохрани туннель.

## 3. На Ubuntu

```bash
cd ~/davartapp
git pull
```

В `infra/.env.staging` добавь в конец (токен одной строкой):

```env
CLOUDFLARE_TUNNEL_TOKEN=сюда_токен_из_кабинета
CORS_ORIGIN=*
S3_PUBLIC_BASE_URL=https://files.твой-домен.ru/davart
```

Запуск туннеля (стек уже должен быть поднят):

```bash
cd ~/davartapp
docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging --profile tunnel up -d
docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging --profile tunnel ps
docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging logs -f cloudflared
```

В логах должно быть `Registered tunnel connection`.

Проверка **с LTE** (не домашний Wi‑Fi):

```bash
curl https://api.твой-домен.ru/api/health
```

Пересобери API после `git pull` (правка ссылок на файлы):

```bash
docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging up -d --build api
```

## 4. Приложение (Mac)

```bash
cd /Users/sadism/Documents/davartapp/apps/mobile
flutter run --dart-define=API_BASE_URL=https://api.твой-домен.ru/api
```

OTP по-прежнему в логах `api` на Ubuntu.

## Если домена ещё нет

Можно временно quick-tunnel (URL каждый раз новый, для проверки LTE):

```bash
docker run --rm --network davart_default cloudflare/cloudflared:latest \
  tunnel --no-autoupdate --url http://api:3000
```

В логах будет `https://….trycloudflare.com` — его подставь в `API_BASE_URL` (+ `/api`). Для постоянной работы нужен свой домен (шаги 1–4).

## Россия

Cloudflare с МТС/Мегафон обычно открывается. Если `health` с LTE не открывается — пиши, сделаем прокси через RU VPS вместо Cloudflare.
