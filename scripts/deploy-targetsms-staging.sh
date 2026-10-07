#!/usr/bin/env bash
# Sync TargetSMS provider + env to staging VPS and rebuild API.
#
#   TARGETSMS_PASSWORD=... bash scripts/deploy-targetsms-staging.sh
#   TARGETSMS_PASSWORD=... REMOTE=root@217.198.6.88 bash scripts/deploy-targetsms-staging.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE="${REMOTE:-root@217.198.6.88}"
REMOTE_DIR="${REMOTE_DIR:-davartapp}"

: "${TARGETSMS_PASSWORD:?Set TARGETSMS_PASSWORD}"

echo "==> rsync sms.service.ts"
rsync -avz -e "ssh -o ConnectTimeout=20" \
  "$ROOT/apps/api/src/auth/sms.service.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/auth/"

echo "==> rsync configure script"
rsync -avz -e "ssh -o ConnectTimeout=20" \
  "$ROOT/scripts/configure-targetsms-staging.sh" \
  "$REMOTE:~/$REMOTE_DIR/scripts/"

echo "==> patch env + rebuild api"
ssh -o ConnectTimeout=20 "$REMOTE" \
  "TARGETSMS_LOGIN=${TARGETSMS_LOGIN:-Awxcss} TARGETSMS_PASSWORD=${TARGETSMS_PASSWORD} TARGETSMS_SENDER=${TARGETSMS_SENDER:-DAVart.ru} REMOTE_DIR=\$HOME/$REMOTE_DIR" \
  'bash -s' <<'EOF'
set -euo pipefail
cd "$REMOTE_DIR"
chmod +x scripts/configure-targetsms-staging.sh
export ENV_FILE="$PWD/infra/.env.staging"
bash scripts/configure-targetsms-staging.sh

compose() { docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging "$@"; }

DOCKER_BUILDKIT=0 compose build --pull=false api
compose up -d api
sleep 3
curl -sS http://127.0.0.1:3000/api/health || true
echo
echo "==> done"
EOF
