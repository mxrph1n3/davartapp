#!/usr/bin/env bash
# Capture App Store screenshots from a running iOS Simulator or USB iPhone.
#
# Usage (Simulator — iPhone 17/16 Pro Max preferred):
#   1) Boot simulator, run:
#        cd apps/mobile && flutter run -d "iPhone 17 Pro Max" --dart-define-from-file=dart_defines.play.json
#   2) Open the screen you want (login / chat / catalog / project)
#   3) Run:
#        bash scripts/capture-appstore-screenshots.sh chat
#        bash scripts/capture-appstore-screenshots.sh catalog
#        bash scripts/capture-appstore-screenshots.sh project
#        bash scripts/capture-appstore-screenshots.sh login
#
# USB iPhone:
#   Connect cable (wireless screenshot is not supported), open the screen, then:
#        flutter screenshot -d <deviceId> -o apps/mobile/store_assets/appstore/from_device/raw_NAME.png
#   Then:
#        bash scripts/capture-appstore-screenshots.sh --from-file raw_NAME.png NAME
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/apps/mobile/store_assets/appstore/from_device"
UPLOAD="$ROOT/apps/mobile/store_assets/appstore/upload"
mkdir -p "$OUT" "$UPLOAD/iphone_6.7" "$UPLOAD/iphone_6.5" "$UPLOAD/iphone_6.1"

name="${1:-}"
if [[ "$name" == "--from-file" ]]; then
  src="$2"
  name="${3:?name required}"
  [[ -f "$src" ]] || { echo "missing $src"; exit 1; }
else
  [[ -n "$name" ]] || { echo "usage: $0 <login|chat|catalog|project>"; exit 1; }
  SIM="$(xcrun simctl list devices | awk '/Booted/{print}' | grep -oE '[A-F0-9-]{36}' | head -1 || true)"
  [[ -n "$SIM" ]] || { echo "No booted simulator. Boot iPhone 17 Pro Max first."; exit 1; }
  src="$OUT/raw_${name}.png"
  echo "==> screenshot simulator $SIM → $src"
  xcrun simctl io "$SIM" screenshot "$src"
fi

# Copy lossless master
cp "$src" "$OUT/${name}_native.png"
w="$(sips -g pixelWidth "$src" | awk '/pixelWidth/{print $2}')"
h="$(sips -g pixelHeight "$src" | awk '/pixelHeight/{print $2}')"
echo "==> native ${w}x${h}"

# Exact App Store sizes via high-quality pad/crop (no JPEG recompression)
# Prefer letterbox on black if aspect differs slightly.
export_size() {
  local tw="$1" th="$2" dest="$3"
  # Scale to cover then crop center — keeps sharpness better than stretch
  python3 - "$src" "$tw" "$th" "$dest" <<'PY'
import sys
from pathlib import Path
try:
    from PIL import Image
except ImportError:
    sys.exit(2)
src, tw, th, dest = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
im = Image.open(src).convert("RGB")
sw, sh = im.size
scale = max(tw / sw, th / sh)
nw, nh = int(round(sw * scale)), int(round(sh * scale))
im = im.resize((nw, nh), Image.Resampling.LANCZOS)
left = (nw - tw) // 2
top = (nh - th) // 2
im = im.crop((left, top, left + tw, top + th))
Path(dest).parent.mkdir(parents=True, exist_ok=True)
im.save(dest, format="PNG", optimize=False, compress_level=1)
print(dest)
PY
}

order_chat=01; order_catalog=02; order_project=03; order_login=04
case "$name" in
  chat) idx=01 ;;
  catalog) idx=02 ;;
  project) idx=03 ;;
  login) idx=04 ;;
  *) idx=99 ;;
esac

if export_size 1290 2796 "$UPLOAD/iphone_6.7/${idx}_${name}_1290x2796.png" 2>/dev/null; then
  export_size 1242 2688 "$UPLOAD/iphone_6.5/${idx}_${name}_1242x2688.png"
  export_size 1179 2556 "$UPLOAD/iphone_6.1/${idx}_${name}_1179x2556.png"
  # Also keep 1320x2868 if native is already that (Pro Max) — Apple accepts it for 6.7"
  if [[ "$w" == "1320" && "$h" == "2868" ]]; then
    cp "$src" "$UPLOAD/iphone_6.7/${idx}_${name}_1320x2868.png"
  fi
  echo "==> wrote App Store PNGs for $name"
else
  echo "==> Pillow missing — copying native only; install with: python3 -m pip install pillow"
  cp "$src" "$UPLOAD/iphone_6.7/${idx}_${name}_native.png"
fi

open "$OUT"
echo "Done: $OUT/${name}_native.png"
