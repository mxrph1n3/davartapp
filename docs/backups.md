# Бэкапы Postgres и MinIO

Чаты и вложения живут на одном VPS: Postgres (сообщения) + том MinIO (файлы). Без бэкапа потеря диска = потеря переписки.

Mango / телефония не используются.

## Снять бэкап

С корня репозитория (стек должен быть запущен):

```bash
cd ~/davartapp   # или путь на VPS
sudo mkdir -p /var/backups/davart
sudo chown "$USER" /var/backups/davart
bash scripts/backup-davart.sh
```

Появится каталог `/var/backups/davart/ГГГГММДДT…Z/` с `postgres.dump` и `minio.tgz`.

Переменные:

| Env | По умолчанию |
|-----|----------------|
| `BACKUP_DIR` | `/var/backups/davart` |
| `KEEP_DAYS` | `7` |
| `MINIO_VOLUME` | `davart_minio_data` |
| `ENV_FILE` | `infra/.env.staging` |

Если том MinIO называется иначе: `docker volume ls | grep minio`.

## Cron каждый день

```bash
sudo crontab -e
```

```cron
15 3 * * * cd /home/davart-server/davartapp && BACKUP_DIR=/var/backups/davart KEEP_DAYS=14 bash scripts/backup-davart.sh >> /var/log/davart-backup.log 2>&1
```

Путь `cd` замени на реальный home пользователя на VPS.

Копии лучше периодически увозить **с сервера** (второй диск, S3 Selectel, `rsync` на другой хост).

## Восстановление

```bash
bash scripts/restore-davart.sh /var/backups/davart/20260822T031500Z
```

API останавливается, данные перезаписываются, стек поднимается снова.

## Проверка

После бэкапа:

```bash
ls -lh /var/backups/davart/latest 2>/dev/null || ls -lh /var/backups/davart | tail
file /var/backups/davart/*/postgres.dump
```

`postgres.dump` не должен быть пустым.
