# Staging на Ubuntu — команды для копирования

Репозиторий: https://github.com/mxrph1n3/davartapp

## 1. Обновить код

```bash
cd ~/davartapp
git pull
```

## 2. Создать .env с безопасными паролями

Вариант А — скрипт из репо:

```bash
cd ~/davartapp
bash scripts/setup-staging-env.sh
```

Вариант Б — вручную одной вставкой:

```bash
cd ~/davartapp

NEW_PG=$(openssl rand -hex 16)
NEW_JWT=$(openssl rand -hex 32)
NEW_MEILI=$(openssl rand -hex 32)
NEW_S3=$(openssl rand -hex 16)

LAN_IP=$(hostname -I | awk '{print $1}')

cat > infra/.env.staging <<EOF
POSTGRES_USER=davart
POSTGRES_PASSWORD=${NEW_PG}
POSTGRES_DB=davart

MEILI_MASTER_KEY=${NEW_MEILI}
JWT_SECRET=${NEW_JWT}

CORS_ORIGIN=*

S3_ACCESS_KEY=davart
S3_SECRET_KEY=${NEW_S3}
S3_BUCKET=davart
S3_PUBLIC_BASE_URL=http://${LAN_IP}:9000/davart

SMS_PROVIDER=mock
EOF

cat infra/.env.staging
```

## 3. Пересоздать контейнеры (сотрёт старую локальную БД)

```bash
cd ~/davartapp
docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging down -v
docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging up -d --build
```

## 4. Проверка

```bash
sleep 30
docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging ps
curl http://127.0.0.1:3000/api/health
docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging logs --tail=80 api
```

## 5. Приложение (с телефона / Mac в той же Wi‑Fi)

На Ubuntu узнай IP:

```bash
hostname -I | awk '{print $1}'
```

В Flutter:

```bash
flutter run --dart-define=API_BASE_URL=http://ЭТОТ_IP:3000/api
```

## 6. Seed (после того как health ок)

```bash
docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging exec api npx prisma db seed
```

OTP при `SMS_PROVIDER=mock` смотри в логах:

```bash
docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging logs -f api | grep -i otp
```
