#!/usr/bin/env bash
# Deploy phone-contacts match API + force TargetSMS on staging.
#
#   TARGETSMS_PASSWORD=... bash scripts/deploy-chat-contacts-staging.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE="${REMOTE:-root@217.198.6.88}"
REMOTE_DIR="${REMOTE_DIR:-davartapp}"
: "${TARGETSMS_PASSWORD:?Set TARGETSMS_PASSWORD}"

echo "==> rsync chat API"
rsync -avz -e "ssh -o ConnectTimeout=20" \
  "$ROOT/apps/api/src/auth/sms.service.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/auth/"
rsync -avz -e "ssh -o ConnectTimeout=20" \
  "$ROOT/apps/api/src/chat/chat.service.ts" \
  "$ROOT/apps/api/src/chat/chat.controller.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/chat/"
rsync -avz -e "ssh -o ConnectTimeout=20" \
  "$ROOT/apps/api/src/chat/dto/chat.dto.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/chat/dto/"
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

# Force SMS_PROVIDER=targetsms even if something else re-added it
sed -i '/^SMS_PROVIDER=/d' infra/.env.staging
printf '%s\n' 'SMS_PROVIDER=targetsms' >> infra/.env.staging

compose() { docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging "$@"; }
DOCKER_BUILDKIT=0 compose build --pull=false api
compose up -d api
sleep 3
compose exec -T api printenv | grep -E 'SMS_PROVIDER|TARGETSMS_LOGIN|TARGETSMS_SENDER' || true
curl -sS http://127.0.0.1:3000/api/health || true
echo
echo "==> done"
EOF
