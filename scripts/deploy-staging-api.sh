#!/usr/bin/env bash
# Deploy API to staging VPS. Run from your Mac (needs SSH to the server):
#
#   bash scripts/deploy-staging-api.sh
#   bash scripts/deploy-staging-api.sh root@217.198.6.88
#   REMOTE_DIR=/opt/davartapp bash scripts/deploy-staging-api.sh user@host

set -euo pipefail

REMOTE="${1:-root@217.198.6.88}"
REMOTE_DIR="${REMOTE_DIR:-\$HOME/davartapp}"

echo "==> deploying to ${REMOTE}:${REMOTE_DIR}"
ssh -o ConnectTimeout=20 "$REMOTE" "REMOTE_DIR=$REMOTE_DIR" 'bash -s' <<'EOF'
set -euo pipefail
cd "$REMOTE_DIR"
echo "==> cwd: $(pwd)"
echo "==> before: $(git rev-parse --short HEAD)"
git pull origin main
echo "==> after:  $(git rev-parse --short HEAD)"

if command -v docker-compose >/dev/null 2>&1; then
  compose() { docker-compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging "$@"; }
else
  compose() { docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging "$@"; }
fi

echo "==> rebuild api"
compose up -d --build api

echo "==> migrate"
compose exec -T api npx prisma migrate deploy

echo "==> health"
sleep 4
curl -sS http://127.0.0.1:3000/api/health || true
echo

echo "==> check OTP_LENGTH in built api"
compose exec -T api sh -c 'grep -R "OTP_LENGTH" dist/auth/auth.service.js | head -3 || true'
echo "==> done"
EOF
