#!/usr/bin/env bash
# One command: pull + clean deps + install DAVart on a physical iPhone (VPS API).
#
#   bash scripts/run-ios-device.sh
#   bash scripts/run-ios-device.sh --xcode
#   bash scripts/run-ios-device.sh 217.198.6.88
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
command -v pod >/dev/null || die "CocoaPods не найден. Установи: sudo gem install cocoapods"

echo "==> repo: ${ROOT}"
echo "==> API_BASE_URL=${API_BASE}"
printf '%s\n' "{\"API_BASE_URL\":\"${API_BASE}\"}" > "$DEFINES_FILE"

cd "$MOBILE"

# SPM off — всё через CocoaPods (как в рабочей установке)
echo "==> flutter config --no-enable-swift-package-manager"
flutter config --no-enable-swift-package-manager

echo "==> flutter clean"
flutter clean

echo "==> flutter pub get"
flutter pub get

echo "==> plugins:"
ls ios/.symlinks/plugins 2>/dev/null || true

echo "==> reset Pods / .symlinks"
rm -rf ios/Pods ios/.symlinks ios/Podfile.lock

echo "==> flutter pub get (после сброса pods)"
flutter pub get

echo "==> pod install --repo-update"
(
  cd ios
  pod install --repo-update
)

echo
echo "Xcode signing (один раз на Mac):"
echo "  open ios/Runner.xcworkspace"
echo "  Runner → Signing & Capabilities → Team = твой Apple ID"
echo "  iPhone по кабелю → Trust → Developer Mode ON"
echo

if [[ "$OPEN_XCODE" -eq 1 ]]; then
  echo "==> flutter build ios (debug) + открыть Xcode → Product → Run (⌘R)"
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
