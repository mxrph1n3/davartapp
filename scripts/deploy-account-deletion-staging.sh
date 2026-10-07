#!/usr/bin/env bash
# Deploy in-app account deletion (DELETE /api/users/me) to staging.
# Usage: bash scripts/deploy-account-deletion-staging.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE="${REMOTE:-root@217.198.6.88}"
REMOTE_DIR="${REMOTE_DIR:-davartapp}"

echo "==> rsync users API"
rsync -avz -e "ssh -o ConnectTimeout=25" \
  "$ROOT/apps/api/src/users/users.controller.ts" \
  "$ROOT/apps/api/src/users/users.service.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/users/"

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

echo
echo "Done. Test: login + DELETE /api/users/me"
