#!/usr/bin/env bash
# Staging env for VPS / LAN.
#   PUBLIC_IP=217.198.6.88 SMSRU_API_ID=xxx bash scripts/setup-staging-env.sh
#
# Or on the server itself (auto LAN/public IP):
#   cd ~/davartapp && bash scripts/setup-staging-env.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

NEW_PG=$(openssl rand -hex 16)
NEW_JWT=$(openssl rand -hex 32)
NEW_MEILI=$(openssl rand -hex 32)
NEW_S3=$(openssl rand -hex 16)

if [[ -n "${PUBLIC_IP:-}" ]]; then
  HOST_IP="$PUBLIC_IP"
else
  HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
fi

if [[ -z "${HOST_IP}" ]]; then
  echo "Не удалось определить IP. Задай PUBLIC_IP=…"
  HOST_IP="CHANGE_ME"
fi

SMS_PROVIDER="${SMS_PROVIDER:-mock}"
SMSRU_LINE=""
if [[ -n "${SMSRU_API_ID:-}" ]]; then
  SMS_PROVIDER=smsru
  SMSRU_LINE="SMSRU_API_ID=${SMSRU_API_ID}"
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
S3_PUBLIC_BASE_URL=http://${HOST_IP}:9000/davart

SMS_PROVIDER=${SMS_PROVIDER}
${SMSRU_LINE}
EOF

echo "OK: записан ${ROOT}/infra/.env.staging"
echo "Public IP: ${HOST_IP}"
echo "SMS_PROVIDER: ${SMS_PROVIDER}"
echo
echo "Дальше на сервере:"
echo "  docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging up -d --build"
echo "  curl http://127.0.0.1:3000/api/health"
echo
echo "На телефоне (Xcode / flutter):"
echo "  --dart-define=API_BASE_URL=http://${HOST_IP}:3000/api"
