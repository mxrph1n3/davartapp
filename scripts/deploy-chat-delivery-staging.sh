#!/usr/bin/env bash
# Deploy chat delivery fixes (socket fan-out) to staging.
# Usage: bash scripts/deploy-chat-delivery-staging.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE="${REMOTE:-root@217.198.6.88}"
REMOTE_DIR="${REMOTE_DIR:-davartapp}"

echo "==> rsync chat gateway/controller"
rsync -avz -e "ssh -o ConnectTimeout=25" \
  "$ROOT/apps/api/src/chat/chat.gateway.ts" \
  "$ROOT/apps/api/src/chat/chat.controller.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/chat/"

echo "==> rebuild api"
ssh -o ConnectTimeout=25 "$REMOTE" bash -s <<EOF
set -euo pipefail
cd ~/$REMOTE_DIR
compose() { docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging "\$@"; }
DOCKER_BUILDKIT=0 compose build --pull=false api
compose up -d api
sleep 5
curl -sS http://127.0.0.1:3000/api/health; echo
EOF

echo "Done."
