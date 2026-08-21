# CRM на Reg.ru (заготовка)

Sprint 20 закрывает **заготовку** выкладки, не живой прод. Живой поддомен зоны DA art настраивает ops после DNS и SSL.

Локально CRM проксирует `/api` на Nest (`next.config.ts`). В production можно оставить прокси через nginx или задать абсолютный `NEXT_PUBLIC_API_URL` — тогда нужны HTTPS и CORS.

## Сборка

```bash
cd apps/admin
cp .env.local.example .env.production.local
# NEXT_PUBLIC_API_URL=https://api.davart.ru/api
npm ci
npm run build
```

Артефакт: `apps/admin/.next/standalone` + `.next/static` + `public`.

Запуск (пример):

```bash
PORT=3001 HOSTNAME=127.0.0.1 node apps/admin/.next/standalone/apps/admin/server.js
```

Точный путь `server.js` зависит от структуры monorepo при `output: 'standalone'`. Если Next положит файл в корень standalone — запускать его.

## Env

| Переменная | Где | Пример |
|------------|-----|--------|
| `NEXT_PUBLIC_API_URL` | CRM | `https://api.davart.ru/api` |
| `CRM_WEB_URL` | API | `https://crm.davart.ru` |
| `CORS_ORIGIN` | API | `https://crm.davart.ru` |
| `APP_PUBLIC_URL` | API | запасной URL, если `CRM_WEB_URL` пуст |

Telegram-кнопка «Открыть заказ» требует **HTTPS**. HTTP на localhost в проде кнопка не примет.

## nginx (поддомен 3-го уровня)

```nginx
server {
    listen 443 ssl http2;
    server_name crm.davart.ru;

    ssl_certificate     /etc/nginx/ssl/crm.davart.ru.fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/crm.davart.ru.key;

    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 80;
    server_name crm.davart.ru;
    return 301 https://$host$request_uri;
}
```

API (`api.davart.ru`) проксируется отдельно на Nest `:3000`. Не смешивать SPA и API на одном origin без префикса — сейчас фронт ждёт абсолютный `NEXT_PUBLIC_API_URL`.

## systemd (набросок)

```ini
[Unit]
Description=Davart CRM
After=network.target

[Service]
Type=simple
WorkingDirectory=/var/www/davart/apps/admin
Environment=PORT=3001
Environment=HOSTNAME=127.0.0.1
Environment=NODE_ENV=production
ExecStart=/usr/bin/node .next/standalone/apps/admin/server.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

## Чеклист перед включением DNS

1. `npx prisma migrate deploy` на API (поле `users.birth_date`)
2. `CORS_ORIGIN` содержит origin CRM
3. `CRM_WEB_URL=https://crm.…` — кнопки Telegram ведут в карточку заказа
4. OTP: `SMS_PROVIDER=smsru` (mock только на staging)
5. Проверка: комплектатор логинится → клиент → вкладка История по ссылке `/clients/{id}/orders/{orderId}`
