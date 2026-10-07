#!/usr/bin/env bash
# Run ON the VPS after: ssh root@217.198.6.88
# Verifies two accounts can message each other via localhost API + Redis OTP inject.
#
#   bash scripts/vps-verify-messenger.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

API="${API:-http://127.0.0.1:3000/api}"
PHONE_A="${PHONE_A:-+79001110001}"
PHONE_B="${PHONE_B:-+79001110002}"
OTP="${OTP:-4242}"
COMPOSE=(docker compose -f infra/docker-compose.staging.yml --env-file infra/.env.staging)

hash_otp() {
  python3 - <<PY
import hashlib
print(hashlib.sha256(b"davart-otp:${OTP}").hexdigest())
PY
}

echo "==> health"
curl -fsS "$API/health" | python3 -m json.tool >/dev/null
echo OK

H="$(hash_otp)"
echo "==> inject OTP $OTP into redis"
"${COMPOSE[@]}" exec -T redis redis-cli DEL "otp:rate:${PHONE_A}" "otp:rate:${PHONE_B}" \
  "otp:verify:lock:${PHONE_A}" "otp:verify:lock:${PHONE_B}" >/dev/null || true
"${COMPOSE[@]}" exec -T redis redis-cli SET "otp:${PHONE_A}" "$H" EX 300 >/dev/null
"${COMPOSE[@]}" exec -T redis redis-cli SET "otp:${PHONE_B}" "$H" EX 300 >/dev/null

login() {
  local phone="$1"
  curl -fsS -X POST "$API/auth/verify-otp" \
    -H 'Content-Type: application/json' \
    -d "{\"phone\":\"$phone\",\"code\":\"$OTP\"}"
}

echo "==> login A/B"
A_JSON="$(login "$PHONE_A")"
B_JSON="$(login "$PHONE_B")"
TOKEN_A="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["accessToken"])' <<<"$A_JSON")"
TOKEN_B="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["accessToken"])' <<<"$B_JSON")"
ID_A="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])' <<<"$A_JSON")"
ID_B="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])' <<<"$B_JSON")"
echo "A=$ID_A B=$ID_B"

echo "==> personal chat"
CHAT_JSON="$(curl -fsS -X POST "$API/chats/personal" \
  -H "Authorization: Bearer $TOKEN_A" \
  -H 'Content-Type: application/json' \
  -d "{\"userId\":\"$ID_B\"}")"
CHAT_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])' <<<"$CHAT_JSON")"
echo "chat=$CHAT_ID"

MSG_A="ping-from-A-$(date +%s)"
MSG_B="pong-from-B-$(date +%s)"

echo "==> A -> B: $MSG_A"
curl -fsS -X POST "$API/chats/$CHAT_ID/messages" \
  -H "Authorization: Bearer $TOKEN_A" \
  -H 'Content-Type: application/json' \
  -d "{\"type\":\"text\",\"content\":\"$MSG_A\"}" >/dev/null

echo "==> B reads"
B_MSGS="$(curl -fsS "$API/chats/$CHAT_ID/messages?limit=30" \
  -H "Authorization: Bearer $TOKEN_B")"
python3 - <<PY
import json,sys
items=json.loads('''$B_MSGS''')["items"]
texts=[m.get("content") for m in items]
assert "$MSG_A" in texts, texts
print("OK B sees A message")
PY

echo "==> B -> A: $MSG_B"
curl -fsS -X POST "$API/chats/$CHAT_ID/messages" \
  -H "Authorization: Bearer $TOKEN_B" \
  -H 'Content-Type: application/json' \
  -d "{\"type\":\"text\",\"content\":\"$MSG_B\"}" >/dev/null

A_MSGS="$(curl -fsS "$API/chats/$CHAT_ID/messages?limit=30" \
  -H "Authorization: Bearer $TOKEN_A")"
python3 - <<PY
import json
items=json.loads('''$A_MSGS''')["items"]
texts=[m.get("content") for m in items]
assert "$MSG_B" in texts, texts
print("OK A sees B reply")
PY

echo
echo "PASS: messenger OK — accounts can write to each other"
echo "chat_id=$CHAT_ID"
