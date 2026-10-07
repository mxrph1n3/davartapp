#!/usr/bin/env bash
# Deploy catalog image fallbacks so Play/review never sees grey placeholders.
# Usage: bash scripts/deploy-catalog-images-staging.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE="${REMOTE:-root@217.198.6.88}"
REMOTE_DIR="${REMOTE_DIR:-davartapp}"

echo "==> rsync catalog/commerce image fallbacks"
rsync -avz -e "ssh -o ConnectTimeout=25" \
  "$ROOT/apps/api/src/catalog/demo-product-image.ts" \
  "$ROOT/apps/api/src/catalog/catalog.service.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/catalog/"
rsync -avz -e "ssh -o ConnectTimeout=25" \
  "$ROOT/apps/api/src/commerce/cart.service.ts" \
  "$ROOT/apps/api/src/commerce/favorites.service.ts" \
  "$REMOTE:~/$REMOTE_DIR/apps/api/src/commerce/"

echo "==> rebuild api"
ssh -o ConnectTimeout=25 "$REMOTE" bash -s <<EOF
set -euo pipefail
cd ~/$REMOTE_DIR
compose() { docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging "\$@"; }
DOCKER_BUILDKIT=0 compose build --pull=false api
compose up -d api
sleep 5
curl -sS 'http://127.0.0.1:3000/api/catalog/products?limit=3' | head -c 400; echo
EOF

echo
echo "Done."
