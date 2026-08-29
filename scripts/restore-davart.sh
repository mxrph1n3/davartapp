#!/usr/bin/env bash
# Restore from a backup directory created by backup-davart.sh
# Usage:
#   bash scripts/restore-davart.sh /var/backups/davart/20260822T001500Z
#
# Stops API, restores Postgres + MinIO volume, starts stack.
# THIS OVERWRITES live data.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/backup-dir" >&2
  exit 1
fi

SRC="$(cd "$1" && pwd)"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENV_FILE="${ENV_FILE:-infra/.env.staging}"
COMPOSE_FILE="${COMPOSE_FILE:-infra/docker-compose.staging.yml}"
MINIO_VOLUME="${MINIO_VOLUME:-davart_minio_data}"

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

if [[ ! -f "$SRC/postgres.dump" ]]; then
  echo "Missing $SRC/postgres.dump" >&2
  exit 1
fi

echo "Restore from $SRC — live data will be overwritten."
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" stop api || true

echo "==> Postgres"
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T postgres \
  pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists \
  < "$SRC/postgres.dump"

if [[ -f "$SRC/minio.tgz" ]]; then
  echo "==> MinIO volume $MINIO_VOLUME"
  docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" stop minio api || true
  docker run --rm \
    -v "${MINIO_VOLUME}:/data" \
    -v "${SRC}:/backup:ro" \
    alpine:3.20 \
    sh -c "rm -rf /data/* /data/.[!.]* 2>/dev/null; tar xzf /backup/minio.tgz -C /data"
fi

docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
echo "OK restore $SRC"
