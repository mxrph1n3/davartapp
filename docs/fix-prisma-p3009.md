# Если API рестартится с Prisma P3009

Ошибка значит: в Postgres осталась **проваленная** миграция
`20260817130000_project_members`. Пока она в статусе failed, API не стартует.

На домашнем staging **данных жалеть не нужно** — проще стереть том БД.

## Полный сброс (рекомендуется)

```bash
cd ~/davartapp
git pull

docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging down -v

# убедиться, что тома удалились
docker volume ls | grep -i davart || true

docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging up -d --build

sleep 40
docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging ps
curl http://127.0.0.1:3000/api/health
docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging logs --tail=40 api
```

Важно: флаг **`-v`** — без него старая битая БД останется и ошибка повторится.

## Если volumes с другим именем не удалились

```bash
docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging down -v
docker volume ls
# удали вручную то, что похоже на postgres:
# docker volume rm ИМЯ_ТОМА
```

## Seed после успешного health

```bash
docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging exec api npx prisma db seed
```
