#!/usr/bin/env bash
# One command: deps + install DAVart on a physical iPhone against the VPS API.
#
#   bash scripts/run-ios-device.sh
#   bash scripts/run-ios-device.sh 217.198.6.88
#   bash scripts/run-ios-device.sh --xcode          # deps + open Xcode (Product → Run)
#   DEVICE_ID=00008110-… bash scripts/run-ios-device.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="217.198.6.88"
OPEN_XCODE=0

for arg in "$@"; do
  case "$arg" in
    --xcode) OPEN_XCODE=1 ;;
    -h|--help)
      sed -n '2,10p' "$0"
      exit 0
      ;;
    *) HOST="$arg" ;;
  esac
done

API_BASE="http://${HOST}:3000/api"
MOBILE="$ROOT/apps/mobile"
DEFINES_FILE="$MOBILE/dart_defines.device.json"

die() { echo "error: $*" >&2; exit 1; }

command -v flutter >/dev/null || die "Flutter не найден. Установи: https://docs.flutter.dev/get-started/install/macos"
command -v xcodebuild >/dev/null || die "Xcode не найден. Установи Xcode из App Store и открой один раз."

cd "$MOBILE"

echo "==> API_BASE_URL=${API_BASE}"
printf '%s\n' "{\"API_BASE_URL\":\"${API_BASE}\"}" > "$DEFINES_FILE"
echo "==> wrote ${DEFINES_FILE}"

echo "==> flutter pub get"
flutter pub get

if [[ -d ios ]]; then
  echo "==> pod install"
  (
    cd ios
    if ! command -v pod >/dev/null; then
      die "CocoaPods не найден. Установи: sudo gem install cocoapods"
    fi
    pod install --repo-update
  )
fi

echo
echo "Xcode signing (один раз на Mac):"
echo "  open ios/Runner.xcworkspace"
echo "  Runner → Signing & Capabilities → Team = твой Apple ID"
echo "  iPhone по кабелю → Trust → Developer Mode ON"
echo

if [[ "$OPEN_XCODE" -eq 1 ]]; then
  echo "==> flutter build ios (debug) с API на VPS — потом Product → Run в Xcode"
  flutter build ios --debug --no-codesign \
    --dart-define-from-file="$DEFINES_FILE"
  open "$MOBILE/ios/Runner.xcworkspace"
  echo
  echo "В Xcode: выбери свой iPhone сверху → Product → Run (⌘R)."
  exit 0
fi

if [[ -n "${DEVICE_ID:-}" ]]; then
  exec flutter run \
    --dart-define-from-file="$DEFINES_FILE" \
    -d "${DEVICE_ID}"
fi

echo "==> устройства:"
flutter devices
echo

# Prefer first connected physical iOS device (not simulator / chrome / macos).
pick_device() {
  flutter devices --machine 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for d in data:
    if d.get("targetPlatform") != "ios":
        continue
    if d.get("emulator") is True:
        continue
    print(d.get("id", ""))
    break
' || true
}

DEVICE="$(pick_device || true)"
if [[ -n "${DEVICE}" ]]; then
  echo "==> flutter run на ${DEVICE}"
  exec flutter run \
    --dart-define-from-file="$DEFINES_FILE" \
    -d "${DEVICE}"
fi

echo "==> физический iPhone не найден — запускаю flutter run (выбери устройство)"
exec flutter run --dart-define-from-file="$DEFINES_FILE"
