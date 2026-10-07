#!/usr/bin/env bash
# Capture real App Store screenshots from booted Simulator (native PNG, no mock).
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$PATH

SIM="$(xcrun simctl list devices | awk '/Booted/{print}' | grep -oE '[A-F0-9-]{36}' | head -1 || true)"
[[ -n "$SIM" ]] || { echo "Boot iPhone 17 Pro Max first"; exit 1; }

OUT=/Users/sadism/Documents/davartapp/apps/mobile/store_assets/appstore/from_device
UPLOAD=/Users/sadism/Documents/davartapp/apps/mobile/store_assets/appstore/upload
mkdir -p "$OUT" "$UPLOAD/iphone_6.7" "$UPLOAD/iphone_6.5" "$UPLOAD/iphone_6.1"

# Drop old compressed marketing mocks from upload dirs
rm -f "$UPLOAD/iphone_6.7/"*.png "$UPLOAD/iphone_6.5/"*.png "$UPLOAD/iphone_6.1/"*.png 2>/dev/null || true

open -a Simulator
xcrun simctl launch "$SIM" com.davart.app >/dev/null 2>&1 || true
sleep 1.2

click_open_alert() {
  # Click the iOS "Open in DAVart?" confirmation after simctl openurl.
  osascript <<'APPLESCRIPT' >/dev/null 2>&1 || true
tell application "Simulator" to activate
delay 0.35
tell application "System Events"
  tell process "Simulator"
    set frontmost to true
    delay 0.2
    repeat 4 times
      try
        if exists sheet 1 of window 1 then
          try
            click button "Открыть" of sheet 1 of window 1
          on error
            try
              click button "Open" of sheet 1 of window 1
            end try
          end try
          delay 0.5
        else
          exit repeat
        end if
      on error
        exit repeat
      end try
    end repeat
  end tell
end tell
APPLESCRIPT
}

# Coordinate click on "Открыть" as backup (center-right of alert on 6.7" frame)
click_open_coords() {
  osascript <<'APPLESCRIPT' >/dev/null 2>&1 || true
tell application "Simulator" to activate
delay 0.2
tell application "System Events"
  tell process "Simulator"
    set frontmost to true
    set win to window 1
    set {x, y} to position of win
    set {w, h} to size of win
    -- Alert Open button roughly center-right of device mid
    set clickX to x + (w * 0.62)
    set clickY to y + (h * 0.52)
    click at {clickX, clickY}
  end tell
end tell
APPLESCRIPT
}

export_shot() {
  local idx="$1" name="$2" route="$3"
  echo "==> $name ($route)"
  xcrun simctl openurl "$SIM" "davart://go${route}" || true
  sleep 0.8
  click_open_alert
  sleep 0.3
  click_open_coords
  sleep 2.0
  local raw="$OUT/${idx}_${name}_1320x2868.png"
  xcrun simctl io "$SIM" screenshot --type=png "$raw"
  cp "$raw" "$UPLOAD/iphone_6.7/${idx}_${name}_1320x2868.png"
  sips -z 2796 1290 "$raw" --out "$UPLOAD/iphone_6.7/${idx}_${name}_1290x2796.png" >/dev/null
  sips -z 2688 1242 "$raw" --out "$UPLOAD/iphone_6.5/${idx}_${name}_1242x2688.png" >/dev/null
  sips -z 2556 1179 "$raw" --out "$UPLOAD/iphone_6.1/${idx}_${name}_1179x2556.png" >/dev/null
  local bytes
  bytes=$(wc -c <"$raw" | tr -d ' ')
  echo -n "    "
  sips -g pixelWidth -g pixelHeight "$raw" | awk '/pixel/{printf "%s=%s ", $1, $2}'
  echo "bytes=$bytes"
}

export_shot 01 catalog /catalog
export_shot 02 projects /projects
export_shot 03 chats /chat
export_shot 04 profile /profile

# Also refresh legacy 6.7/6.5/6.1 folders used in LISTING.md
mkdir -p \
  /Users/sadism/Documents/davartapp/apps/mobile/store_assets/appstore/6.7 \
  /Users/sadism/Documents/davartapp/apps/mobile/store_assets/appstore/6.5 \
  /Users/sadism/Documents/davartapp/apps/mobile/store_assets/appstore/6.1
cp "$UPLOAD/iphone_6.7/"*_1290x2796.png /Users/sadism/Documents/davartapp/apps/mobile/store_assets/appstore/6.7/ 2>/dev/null || true
cp "$UPLOAD/iphone_6.5/"*.png /Users/sadism/Documents/davartapp/apps/mobile/store_assets/appstore/6.5/ 2>/dev/null || true
cp "$UPLOAD/iphone_6.1/"*.png /Users/sadism/Documents/davartapp/apps/mobile/store_assets/appstore/6.1/ 2>/dev/null || true

open "$UPLOAD/iphone_6.7"
echo
echo "Masters: $OUT"
echo "Upload:  $UPLOAD/iphone_6.7 (use *_1320x2868.png — native Simulator PNG)"
