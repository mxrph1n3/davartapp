#!/usr/bin/env bash
# Backup Postgres (logical dump) + MinIO volume (tar).
# Usage (from repo root):
#   bash scripts/backup-davart.sh
# Cron (daily 03:15):
#   15 3 * * * cd /home/davart-server/davartapp && bash scripts/backup-davart.sh >> /var/log/davart-backup.log 2>&1

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENV_FILE="${ENV_FILE:-infra/.env.staging}"
COMPOSE_FILE="${COMPOSE_FILE:-infra/docker-compose.staging.yml}"
BACKUP_ROOT="${BACKUP_DIR:-/var/backups/davart}"
KEEP_DAYS="${KEEP_DAYS:-7}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DEST="$BACKUP_ROOT/$STAMP"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE" >&2
  exit 1
fi

env_val() {
  local key="$1"
  local line
  line="$(grep -E "^${key}=" "$ENV_FILE" | tail -n1 || true)"
  echo "${line#*=}"
}

POSTGRES_USER="$(env_val POSTGRES_USER)"
POSTGRES_DB="$(env_val POSTGRES_DB)"
POSTGRES_USER="${POSTGRES_USER:-davart}"
POSTGRES_DB="${POSTGRES_DB:-davart}"

mkdir -p "$DEST"

echo "==> Postgres dump → $DEST/postgres.dump"
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T postgres \
  pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc > "$DEST/postgres.dump"

MINIO_VOLUME="${MINIO_VOLUME:-davart_minio_data}"
echo "==> MinIO volume $MINIO_VOLUME → $DEST/minio.tgz"
if docker volume inspect "$MINIO_VOLUME" >/dev/null 2>&1; then
  docker run --rm \
    -v "${MINIO_VOLUME}:/data:ro" \
    -v "${DEST}:/backup" \
    alpine:3.20 \
    tar czf /backup/minio.tgz -C /data .
else
  echo "WARN: volume $MINIO_VOLUME not found, skip MinIO" >&2
fi

echo "$STAMP" > "$DEST/README.txt"
echo "Postgres: pg_dump -Fc" >> "$DEST/README.txt"
echo "MinIO: tar of docker volume $MINIO_VOLUME" >> "$DEST/README.txt"

if [[ "${KEEP_DAYS}" =~ ^[0-9]+$ ]] && [[ "$KEEP_DAYS" -gt 0 ]]; then
  echo "==> prune backups older than ${KEEP_DAYS} days"
  find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime "+${KEEP_DAYS}" -exec rm -rf {} +
fi

echo "OK $DEST"
ls -lh "$DEST"
