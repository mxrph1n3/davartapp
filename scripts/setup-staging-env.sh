#!/usr/bin/env bash
# Скопируй на Ubuntu и запусти:
#   cd ~/davartapp
#   bash scripts/setup-staging-env.sh
#
# Или скачай с GitHub (raw) и:
#   bash setup-staging-env.sh
#
# Пересоздаёт infra/.env.staging с безопасными паролями (только hex).
# Старый .env.staging будет перезаписан.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

NEW_PG=$(openssl rand -hex 16)
NEW_JWT=$(openssl rand -hex 32)
NEW_MEILI=$(openssl rand -hex 32)
NEW_S3=$(openssl rand -hex 16)
LAN_IP=$(hostname -I | awk '{print $1}')

if [[ -z "${LAN_IP}" ]]; then
  echo "Не удалось определить LAN IP. Впиши вручную в infra/.env.staging"
  LAN_IP="192.168.1.CHANGE_ME"
fi

mkdir -p infra

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

echo "OK: записан ${ROOT}/infra/.env.staging"
echo "LAN IP: ${LAN_IP}"
echo
echo "Дальше:"
echo "  docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging down -v"
echo "  docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging up -d --build"
echo "  sleep 20"
echo "  curl http://127.0.0.1:3000/api/health"
echo "  docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging logs --tail=50 api"
