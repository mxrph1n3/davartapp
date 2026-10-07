#!/usr/bin/env bash
# Install DAVart on a physical iPhone against the staging VPS API.
#
#   bash scripts/run-ios-device.sh
#   BUNDLE_ID=com.someone.davart bash scripts/run-ios-device.sh   # чужой Apple ID / Personal Team
#   bash scripts/run-ios-device.sh --run
#   bash scripts/run-ios-device.sh --xcode
#   bash scripts/run-ios-device.sh 217.198.6.88
#   DEVICE_ID=00008110-… bash scripts/run-ios-device.sh
#
# Important: Debug builds crash if opened from the Home Screen without Flutter/Xcode
# attached. Prefer the default release install for teammates.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="217.198.6.88"
MODE="release" # release | run | xcode
BUNDLE_ID="${BUNDLE_ID:-}"

for arg in "$@"; do
  case "$arg" in
    --xcode) MODE="xcode" ;;
    --run) MODE="run" ;;
    --release) MODE="release" ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
    *) HOST="$arg" ;;
  esac
done

API_BASE="http://${HOST}:3000/api"
MOBILE="$ROOT/apps/mobile"
DEFINES_FILE="$MOBILE/dart_defines.device.json"
DEFAULT_BUNDLE_ID="com.davart.app"

die() { echo "error: $*" >&2; exit 1; }

command -v flutter >/dev/null || die "Flutter не найден. Установи: https://docs.flutter.dev/get-started/install/macos"
command -v xcodebuild >/dev/null || die "Xcode не найден. Установи Xcode из App Store и открой один раз."
command -v pod >/dev/null || die "CocoaPods не найден. Установи: sudo gem install cocoapods"

echo "==> repo: ${ROOT}"
echo "==> mode: ${MODE}"
echo "==> API_BASE_URL=${API_BASE}"
printf '%s\n' "{\"API_BASE_URL\":\"${API_BASE}\"}" > "$DEFINES_FILE"

cd "$MOBILE"

# Personal Team / другой Apple ID не может подписать чужой Bundle ID + elees team.
if [[ -n "${BUNDLE_ID}" ]]; then
  echo "==> Bundle ID → ${BUNDLE_ID} (локально, не коммить)"
  python3 - <<PY
from pathlib import Path
import re
root = Path("ios")
new = "${BUNDLE_ID}"
pbx = root / "Runner.xcodeproj" / "project.pbxproj"
text = pbx.read_text()
# Replace any current Runner app id (default or previously patched).
text = re.sub(
    r"(PRODUCT_BUNDLE_IDENTIFIER = )com\.[^;]+;",
    lambda m: m.group(0)
    if ".RunnerTests" in m.group(0)
    else f"{m.group(1)}{new};",
    text,
)
text = re.sub(r"\t+DEVELOPMENT_TEAM = [A-Z0-9]+;\n", "", text)
pbx.write_text(text)
for name in ("Debug.xcconfig", "Release.xcconfig"):
    cfg = root / "Flutter" / name
    lines = [
        line
        for line in cfg.read_text().splitlines(True)
        if not line.startswith("DEVELOPMENT_TEAM=")
    ]
    cfg.write_text("".join(lines))
print("patched", pbx, "→", new)
PY
fi

echo "==> flutter config --no-enable-swift-package-manager"
flutter config --no-enable-swift-package-manager

echo "==> flutter pub get"
flutter pub get

if [[ ! -d ios/Pods ]]; then
  echo "==> pod install"
  (
    cd ios
    pod install --repo-update
  )
fi

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

DEVICE="${DEVICE_ID:-$(pick_device || true)}"

case "$MODE" in
  xcode)
    echo "==> open Xcode workspace"
    echo "  Signing: Runner → Signing & Capabilities → Team = твой Apple ID"
    if [[ -z "${BUNDLE_ID}" ]]; then
      echo "  Если Bundle ID занят: BUNDLE_ID=com.твоёимя.davart bash scripts/run-ios-device.sh --xcode"
    fi
    open "$MOBILE/ios/Runner.xcworkspace"
    exit 0
    ;;
  run)
    echo
    echo "Xcode signing: Team = твой Apple ID, Developer Mode ON, Trust"
    echo
    if [[ -n "${DEVICE}" ]]; then
      echo "==> flutter run (debug) на ${DEVICE}"
      exec flutter run \
        --dart-define-from-file="$DEFINES_FILE" \
        -d "${DEVICE}"
    fi
    echo "==> устройства:"
    flutter devices
    exec flutter run --dart-define-from-file="$DEFINES_FILE"
    ;;
  release)
    echo
    echo "Xcode signing: Team = твой Apple ID, Developer Mode ON, Trust"
    if [[ -z "${BUNDLE_ID}" ]]; then
      echo "Если ошибка Bundle Identifier / elees.ru — запускай так:"
      echo "  BUNDLE_ID=com.твоёимя.davart bash scripts/run-ios-device.sh"
    fi
    echo
    if [[ -z "${DEVICE}" ]]; then
      echo "==> устройства:"
      flutter devices
      die "Физический iPhone не найден. Подключи кабель / включи Developer Mode и повтори."
    fi
    echo "==> flutter build ios --release → ${DEVICE}"
    flutter build ios --release --dart-define-from-file="$DEFINES_FILE"
    echo "==> flutter install"
    flutter install -d "${DEVICE}"
    echo
    echo "Готово. Открой DAVart с Home Screen (release не падает без Xcode)."
    echo "API: ${API_BASE}"
    echo "Если iOS пишет Untrusted Developer: Настройки → Основные → VPN и управление устройством → Доверять."
    exit 0
    ;;
esac
