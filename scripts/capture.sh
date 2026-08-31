#!/usr/bin/env bash
# ============================================================================
# capture.sh — produce a rendered image for visual-critic to judge
#
# The critic must look at PIXELS, never at source. Nothing else in the
# pipeline produces an image, so without this the critic either hallucinates
# a judgement from code or refuses. This script is what makes it real.
#
# USAGE
#   ./scripts/capture.sh mac          # running macOS app window
#   ./scripts/capture.sh ios          # booted iOS simulator
#   ./scripts/capture.sh iphone-se    # smallest supported screen (worst case)
#   ./scripts/capture.sh pdf <file>   # an exported PDF, first page
#   ./scripts/capture.sh all          # mac + iphone-se + pdf, for a full pass
#
# OUTPUT
#   captures/<target>-<timestamp>.png  and  captures/latest-<target>.png
#   Prints the path(s) to stdout — feed these to the critic.
# ============================================================================

set -euo pipefail

APP_NAME="${APP_NAME:-YourApp}"
OUT_DIR="captures"
STAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT_DIR"

emit() {
  local target="$1" path="$2"
  cp "$path" "$OUT_DIR/latest-$target.png"
  echo "$path"
}

capture_mac() {
  local out="$OUT_DIR/mac-$STAMP.png"
  local wid
  wid=$(osascript -e "tell application \"$APP_NAME\" to id of window 1" 2>/dev/null) || {
    echo "ERROR: $APP_NAME is not running or has no window. Launch it first." >&2
    exit 1
  }
  screencapture -x -o -l"$wid" "$out"
  emit mac "$out"
}

capture_ios() {
  local device="${1:-booted}" target="${2:-ios}"
  local out="$OUT_DIR/$target-$STAMP.png"
  xcrun simctl io "$device" screenshot "$out" >/dev/null 2>&1 || {
    echo "ERROR: no booted simulator. Run: xcrun simctl boot '<device>'" >&2
    exit 1
  }
  emit "$target" "$out"
}

capture_iphone_se() {
  # Smallest supported screen — where typography and layout fail first.
  # Boot it if it isn't already.
  local udid
  udid=$(xcrun simctl list devices available | grep -m1 "iPhone SE" | grep -oE '[A-F0-9-]{36}') || {
    echo "ERROR: no iPhone SE simulator available." >&2; exit 1
  }
  xcrun simctl boot "$udid" 2>/dev/null || true
  sleep 2
  capture_ios "$udid" "iphone-se"
}

capture_pdf() {
  local pdf="${1:?usage: capture.sh pdf <file.pdf>}"
  local out="$OUT_DIR/pdf-$STAMP.png"
  [[ -f "$pdf" ]] || { echo "ERROR: no such file: $pdf" >&2; exit 1; }
  # Render at print-ish width so type is judgeable, not thumbnail-sized
  sips -s format png --resampleWidth 1400 "$pdf" --out "$out" >/dev/null
  emit pdf "$out"
}

case "${1:-}" in
  mac)       capture_mac ;;
  ios)       capture_ios booted ios ;;
  iphone-se) capture_iphone_se ;;
  pdf)       capture_pdf "${2:-}" ;;
  all)
    capture_mac
    capture_iphone_se
    [[ -n "${2:-}" ]] && capture_pdf "$2"
    ;;
  *)
    echo "usage: $0 {mac|ios|iphone-se|pdf <file>|all [file.pdf]}" >&2
    exit 1
    ;;
esac
