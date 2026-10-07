#!/usr/bin/env bash
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:${PATH:-}"
ROOT="/Users/sadism/Documents/davartapp/apps/mobile"
BASE="$ROOT/android/local-maven"
cd "$ROOT"

fetch_url() {
  local url="$1"
  local path
  path=$(echo "$url" | sed -E 's#https://(repo\.maven\.apache\.org/maven2|dl\.google\.com/dl/android/maven2)/##')
  local dest="$BASE/$path"
  mkdir -p "$(dirname "$dest")"
  if [ -s "$dest" ]; then
    echo "have $dest"
    return 0
  fi
  echo "dl $url"
  curl -fsSL --retry 8 --retry-all-errors --connect-timeout 30 -o "$dest.tmp" "$url"
  mv "$dest.tmp" "$dest"
  case "$url" in
    *.jar)
      pom="${url%.jar}.pom"
      pomdest="${dest%.jar}.pom"
      if [ ! -s "$pomdest" ]; then
        curl -fsSL --retry 3 -o "$pomdest" "$pom" || true
      fi
      ;;
  esac
}

attempt=1
while [ "$attempt" -le 12 ]; do
  echo "===== ATTEMPT $attempt ====="
  set +e
  flutter build appbundle --release --dart-define-from-file=dart_defines.play.json > /tmp/aab-build.log 2>&1
  code=$?
  set -e
  if [ "$code" -eq 0 ]; then
    echo BUILD_OK
    tail -30 /tmp/aab-build.log
    exit 0
  fi
  urls=$(rg -o "https://[^'\"]+\.(jar|aar|pom)" /tmp/aab-build.log | sort -u || true)
  if [ -z "$urls" ]; then
    echo "No downloadable URLs found"
    tail -80 /tmp/aab-build.log
    exit 1
  fi
  echo "$urls" | while IFS= read -r url; do
    [ -n "$url" ] || continue
    fetch_url "$url" || true
  done
  attempt=$((attempt + 1))
done
echo GAVE_UP
tail -80 /tmp/aab-build.log
exit 1
