#!/usr/bin/env bash
# Deploy chat contacts + storage URL fix to staging.
# Usage: bash scripts/deploy-chat-directory-staging.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE="${REMOTE:-root@217.198.6.88}"
REMOTE_DIR="${REMOTE_DIR:-davartapp}"

echo "==> rsync API"
rsync -avz -e "ssh -o ConnectTimeout=20" \
  "$ROOT/apps/api/src/chat/chat.service.ts" \
  "$ROOT/apps/api/src/chat/chat.controller.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/chat/"
rsync -avz -e "ssh -o ConnectTimeout=20" \
  "$ROOT/apps/api/src/chat/dto/chat.dto.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/chat/dto/"
rsync -avz -e "ssh -o ConnectTimeout=20" \
  "$ROOT/apps/api/src/auth/auth.service.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/auth/"
rsync -avz -e "ssh -o ConnectTimeout=20" \
  "$ROOT/apps/api/src/storage/storage.service.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/storage/"

echo "==> rebuild api on VPS (no cache — last deploy skipped new sources)"
ssh -o ConnectTimeout=20 "$REMOTE" bash -s <<EOF
set -euo pipefail
cd ~/$REMOTE_DIR
DOCKER_BUILDKIT=0 docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging build --no-cache api
docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging up -d api
sleep 3
curl -sS http://127.0.0.1:3000/api/health || true
echo
echo "==> done"
EOF
