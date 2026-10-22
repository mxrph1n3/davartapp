#!/usr/bin/env bash
# Deploy chat delivery fixes (socket fan-out) to staging.
# Usage: bash scripts/deploy-chat-delivery-staging.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE="${REMOTE:-root@217.198.6.88}"
REMOTE_DIR="${REMOTE_DIR:-davartapp}"

echo "==> rsync chat delivery + hide-chat migration"
rsync -avz -e "ssh -o ConnectTimeout=25" \
  "$ROOT/apps/api/src/chat/chat.gateway.ts" \
  "$ROOT/apps/api/src/chat/chat.controller.ts" \
  "$ROOT/apps/api/src/chat/chat.service.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/chat/"
rsync -avz -e "ssh -o ConnectTimeout=25" \
  "$ROOT/apps/api/src/chat/dto/chat.dto.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/chat/dto/"
rsync -avz -e "ssh -o ConnectTimeout=25" \
  "$ROOT/apps/api/src/push/push.service.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/push/"
rsync -avz -e "ssh -o ConnectTimeout=25" \
  "$ROOT/apps/api/src/auth/sms.service.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/auth/"
rsync -avz -e "ssh -o ConnectTimeout=25" \
  "$ROOT/apps/api/prisma/schema.prisma" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/prisma/"
rsync -avz -e "ssh -o ConnectTimeout=25" \
  "$ROOT/apps/api/prisma/migrations/20261008000000_hide_project_chat/" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/prisma/migrations/20261008000000_hide_project_chat/"
rsync -avz -e "ssh -o ConnectTimeout=25" \
  "$ROOT/apps/api/prisma/migrations/20261016040000_draft_project_personal_cart/" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/prisma/migrations/20261016040000_draft_project_personal_cart/"
rsync -avz -e "ssh -o ConnectTimeout=25" \
  "$ROOT/apps/api/prisma/migrations/20261019190000_chat_groups_pins/" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/prisma/migrations/20261019190000_chat_groups_pins/"
rsync -avz -e "ssh -o ConnectTimeout=25" \
  "$ROOT/apps/api/src/projects/projects.service.ts" \
  "$ROOT/apps/api/src/projects/projects.controller.ts" \
  "$ROOT/apps/api/src/projects/project-access.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/projects/"
rsync -avz -e "ssh -o ConnectTimeout=25" \
  "$ROOT/apps/api/src/commerce/cart.service.ts" \
  "$ROOT/apps/api/src/commerce/cart.controller.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/commerce/"
rsync -avz -e "ssh -o ConnectTimeout=25" \
  "$ROOT/apps/api/src/commerce/dto/cart.dto.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/commerce/dto/"

rsync -avz -e "ssh -o ConnectTimeout=25" \
  "$ROOT/apps/api/src/staff/staff.service.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/staff/"
rsync -avz -e "ssh -o ConnectTimeout=25" \
  "$ROOT/infra/docker-compose.staging.yml" \
  "$REMOTE:~/$REMOTE_DIR/infra/"

APNS_KEY_ID="$(grep '^APNS_KEY_ID=' "$ROOT/infra/.env.staging" | tail -1 | cut -d= -f2- || true)"
if [[ -f "$ROOT/infra/apns/AuthKey.p8" ]]; then
  echo "==> rsync APNs key"
  ssh -o ConnectTimeout=25 "$REMOTE" "mkdir -p ~/$REMOTE_DIR/infra/apns"
  rsync -avz -e "ssh -o ConnectTimeout=25" \
    "$ROOT/infra/apns/AuthKey.p8" \
    "$REMOTE:~/$REMOTE_DIR/infra/apns/AuthKey.p8"
fi

ssh -o ConnectTimeout=25 "$REMOTE" bash -s <<EOF
set -euo pipefail
cd ~/$REMOTE_DIR
if [[ -f infra/apns/AuthKey.p8 && -n "${APNS_KEY_ID}" ]]; then
  if grep -q '^APNS_KEY_ID=' infra/.env.staging; then
    sed -i "s/^APNS_KEY_ID=.*/APNS_KEY_ID=${APNS_KEY_ID}/" infra/.env.staging
  else
    printf '\nAPNS_KEY_ID=%s\nAPNS_TEAM_ID=C7968P6K9R\nAPNS_BUNDLE_ID=com.davart.app\nAPNS_KEY_PATH=/etc/davart/AuthKey.p8\n' "${APNS_KEY_ID}" >> infra/.env.staging
  fi
  grep -q '^APNS_TEAM_ID=' infra/.env.staging || echo 'APNS_TEAM_ID=C7968P6K9R' >> infra/.env.staging
  grep -q '^APNS_BUNDLE_ID=' infra/.env.staging || echo 'APNS_BUNDLE_ID=com.davart.app' >> infra/.env.staging
  grep -q '^APNS_KEY_PATH=' infra/.env.staging || echo 'APNS_KEY_PATH=/etc/davart/AuthKey.p8' >> infra/.env.staging
  # The API runs as user davart. A root-only 600 key cannot be read, so Apple
  # pushes never leave the server and a closed app stays silent.
  chmod 644 infra/apns/AuthKey.p8
fi
compose() { docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging "\$@"; }
DOCKER_BUILDKIT=0 compose build --pull=false api
compose up -d --force-recreate api
sleep 5
curl -sS http://127.0.0.1:3000/api/health; echo
EOF

echo "Done."
