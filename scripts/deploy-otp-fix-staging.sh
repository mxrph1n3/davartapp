#!/usr/bin/env bash
# Push OTP fix (TTL / prev-code / store-after-send) to staging and rebuild API.
#
#   bash scripts/deploy-otp-fix-staging.sh
#   REMOTE=root@217.198.6.88 bash scripts/deploy-otp-fix-staging.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE="${REMOTE:-root@217.198.6.88}"
REMOTE_DIR="${REMOTE_DIR:-davartapp}"

echo "==> rsync auth.service.ts"
rsync -avz -e "ssh -o ConnectTimeout=20" \
  "$ROOT/apps/api/src/auth/auth.service.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/auth/"

echo "==> rebuild api"
ssh -o ConnectTimeout=20 "$REMOTE" "REMOTE_DIR=\$HOME/$REMOTE_DIR" 'bash -s' <<'EOF'
set -euo pipefail
cd "$REMOTE_DIR"
compose() { docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging "$@"; }
DOCKER_BUILDKIT=0 compose build --pull=false api
compose up -d api
sleep 4
curl -sS http://127.0.0.1:3000/api/health || true
echo
# Clear verify lock for any stuck phones (safe)
compose exec -T redis redis-cli --scan --pattern 'otp:verify:*' | while read -r k; do
  [ -n "$k" ] && compose exec -T redis redis-cli DEL "$k" >/dev/null || true
done
echo "==> done"
EOF
