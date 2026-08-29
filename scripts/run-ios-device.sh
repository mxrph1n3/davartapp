#!/usr/bin/env bash
# Run DAVart on a physical iPhone against the VPS API.
#
#   bash scripts/run-ios-device.sh
#   bash scripts/run-ios-device.sh 217.198.6.88
#   DEVICE_ID=00008110-… bash scripts/run-ios-device.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${1:-217.198.6.88}"
API_BASE="http://${HOST}:3000/api"

cd "$ROOT/apps/mobile"

echo "API_BASE_URL=${API_BASE}"
echo
echo "Xcode (бесплатный Apple ID / Personal Team):"
echo "  1. open ios/Runner.xcworkspace"
echo "  2. Runner → Signing & Capabilities → Team = твой Apple ID"
echo "  3. Bundle ID можно оставить com.davart.davartMobile (или уникальный)"
echo "  4. iPhone по кабелю → Trust → на телефоне: Developer Mode ON"
echo "  5. Product → Run  (или эта команда ниже)"
echo

if [[ -n "${DEVICE_ID:-}" ]]; then
  flutter run --dart-define=API_BASE_URL="${API_BASE}" -d "${DEVICE_ID}"
  exit 0
fi

echo "Подключённые устройства:"
flutter devices
echo
echo "Запуск (выбери device id, если несколько):"
echo "  flutter run --dart-define=API_BASE_URL=${API_BASE} -d <device-id>"
echo
flutter run --dart-define=API_BASE_URL="${API_BASE}"
