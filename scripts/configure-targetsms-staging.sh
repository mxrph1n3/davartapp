#!/usr/bin/env bash
# Patch infra/.env.staging with TargetSMS fallback. Run on VPS or locally before deploy.
#
#   TARGETSMS_LOGIN=Awxcss TARGETSMS_PASSWORD=secret bash scripts/configure-targetsms-staging.sh
#   REMOTE=root@217.198.6.88 bash scripts/configure-targetsms-staging.sh   # patch on server via SSH

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/infra/.env.staging}"

LOGIN="${TARGETSMS_LOGIN:-Awxcss}"
PASSWORD="${TARGETSMS_PASSWORD:?Set TARGETSMS_PASSWORD}"
SENDER="${TARGETSMS_SENDER:-DAVart.ru}"

patch_env() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "Missing $file — run setup-staging-env.sh first"
    exit 1
  fi

  grep -v -E '^(SMS_PROVIDER|SMS_FALLBACK_PROVIDER|SMSRU_API_ID|TARGETSMS_)=' "$file" > "${file}.tmp"
  mv "${file}.tmp" "$file"

  cat >>"$file" <<EOF

SMS_PROVIDER=targetsms
SMS_FALLBACK_PROVIDER=targetsms
TARGETSMS_LOGIN=${LOGIN}
TARGETSMS_PASSWORD=${PASSWORD}
TARGETSMS_SENDER=${SENDER}
EOF

  echo "OK: TargetSMS in $file (SMS_PROVIDER=targetsms, login=${LOGIN}, sender=${SENDER})"
}

if [[ -n "${REMOTE:-}" ]]; then
  REMOTE_DIR="${REMOTE_DIR:-\$HOME/davartapp}"
  ssh -o ConnectTimeout=20 "$REMOTE" \
    "TARGETSMS_LOGIN=${LOGIN} TARGETSMS_PASSWORD=${PASSWORD} TARGETSMS_SENDER=${SENDER} REMOTE_DIR=${REMOTE_DIR}" \
    'bash -s' <<'EOF'
set -euo pipefail
cd "$REMOTE_DIR"
export ENV_FILE="$PWD/infra/.env.staging"
bash scripts/configure-targetsms-staging.sh
EOF
else
  patch_env "$ENV_FILE"
fi
