#!/usr/bin/env bash
# Deploy AUTH_TEST login (no SMS) to staging.
# Usage: bash scripts/deploy-test-login-staging.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE="${REMOTE:-root@217.198.6.88}"
REMOTE_DIR="${REMOTE_DIR:-davartapp}"

echo "==> rsync auth.service.ts + compose"
rsync -avz -e "ssh -o ConnectTimeout=25" \
  "$ROOT/apps/api/src/auth/auth.service.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/auth/"
rsync -avz -e "ssh -o ConnectTimeout=25" \
  "$ROOT/infra/docker-compose.staging.yml" \
  "$REMOTE:~/$REMOTE_DIR/infra/"

echo "==> patch env + rebuild api"
ssh -o ConnectTimeout=25 "$REMOTE" bash -s <<EOF
set -euo pipefail
cd ~/$REMOTE_DIR
ENV=infra/.env.staging
touch "\$ENV"
grep -q "^AUTH_TEST_PHONES=" "\$ENV" 2>/dev/null \
  && sed -i "s|^AUTH_TEST_PHONES=.*|AUTH_TEST_PHONES=+70000000000|" "\$ENV" \
  || echo "AUTH_TEST_PHONES=+70000000000" >> "\$ENV"
grep -q "^AUTH_TEST_CODE=" "\$ENV" 2>/dev/null \
  && sed -i "s|^AUTH_TEST_CODE=.*|AUTH_TEST_CODE=0000|" "\$ENV" \
  || echo "AUTH_TEST_CODE=0000" >> "\$ENV"
echo "==> AUTH_TEST:"; grep "^AUTH_TEST_" "\$ENV"
DOCKER_BUILDKIT=0 docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging build --no-cache api
docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging up -d api
sleep 5
curl -sS http://127.0.0.1:3000/api/health; echo
curl -sS -X POST http://127.0.0.1:3000/api/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"phone":"+70000000000"}'; echo
EOF

echo
echo "OK — test login: +70000000000 / 0000"
