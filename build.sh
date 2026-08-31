#!/bin/bash
# Builds Kitib.app — a minimalist focused-writing app for macOS.
# Requires: Xcode Command Line Tools (xcode-select --install)
# Usage: ./build.sh   → produces ./Kitib.app

set -e
cd "$(dirname "$0")"

APP_NAME="Kitib"
BUNDLE_ID="com.sean.kitib"
BUILD_DIR=".build-app"

# ---- Offline web assets (Mermaid diagrams + KaTeX math) -----------------------
# Kitib renders its preview/export inside a WKWebView. To keep the app fully
# offline, the Mermaid and KaTeX libraries (plus KaTeX's fonts) are vendored
# into Vendor/web and inlined at render time (see Sources/Shared/WebAssets.swift).
# They're fetched once from the npm registry and cached; delete Vendor/web/.ok
# to force a re-download (e.g. to bump versions below).
KATEX_VERSION="0.16.11"
MERMAID_VERSION="10.9.1"
WEB_DIR="Vendor/web"

fetch_web_assets() {
  if [[ -f "$WEB_DIR/.ok" ]]; then
    echo "Web assets present (Vendor/web) — skipping download."
    return 0
  fi
  echo "Fetching offline web assets (KaTeX $KATEX_VERSION, Mermaid $MERMAID_VERSION)..."
  if ! command -v curl >/dev/null 2>&1; then
    echo "  ⚠️  curl not found — cannot fetch web assets. Diagrams/math will not render."
    return 1
  fi
  local tmp; tmp="$(mktemp -d)"
  mkdir -p "$WEB_DIR/fonts"

  # KaTeX — CSS, JS, auto-render, and the woff2 font set, straight from the
  # published npm tarball (contains everything under package/dist).
  if curl -fsSL "https://registry.npmjs.org/katex/-/katex-${KATEX_VERSION}.tgz" -o "$tmp/katex.tgz" \
     && tar -xzf "$tmp/katex.tgz" -C "$tmp"; then
    cp "$tmp/package/dist/katex.min.css"              "$WEB_DIR/"
    cp "$tmp/package/dist/katex.min.js"               "$WEB_DIR/"
    cp "$tmp/package/dist/contrib/auto-render.min.js" "$WEB_DIR/"
    cp "$tmp/package/dist/fonts/"*.woff2              "$WEB_DIR/fonts/"
  else
    echo "  ⚠️  Failed to fetch KaTeX."; rm -rf "$tmp"; return 1
  fi

  # Mermaid — single self-contained minified bundle.
  if curl -fsSL "https://registry.npmjs.org/mermaid/-/mermaid-${MERMAID_VERSION}.tgz" -o "$tmp/mermaid.tgz" \
     && tar -xzf "$tmp/mermaid.tgz" -C "$tmp"; then
    cp "$tmp/package/dist/mermaid.min.js" "$WEB_DIR/"
  else
    echo "  ⚠️  Failed to fetch Mermaid."; rm -rf "$tmp"; return 1
  fi

  rm -rf "$tmp"
  touch "$WEB_DIR/.ok"
  echo "  ✓ Web assets cached in $WEB_DIR"
}

fetch_web_assets || echo "  (continuing without offline web assets)"

echo "Compiling Swift sources..."
mkdir -p "$BUILD_DIR"

# Vendored SwiftTerm (terminal emulator, MIT) — compiled as its own module,
# cached in $BUILD_DIR until a vendor file changes. First build takes a while.
VENDOR_FILES=(Vendor/SwiftTerm/*.swift Vendor/SwiftTerm/Apple/*.swift Vendor/SwiftTerm/Apple/Metal/*.swift Vendor/SwiftTerm/Mac/*.swift)

build_for() {  # $1 = arch, or "" for native
  local ARCH="$1"
  local TAG="${ARCH:-native}"
  local TDIR="$BUILD_DIR/$TAG"
  local TARGETFLAGS=()
  [[ -n "$ARCH" ]] && TARGETFLAGS=(-target "$ARCH-apple-macos13.0")
  mkdir -p "$TDIR"

  if [[ ! -f "$TDIR/libSwiftTerm.a" || -n "$(find Vendor/SwiftTerm -name '*.swift' -newer "$TDIR/libSwiftTerm.a" 2>/dev/null)" ]]; then
    echo "  SwiftTerm ($TAG)…"
    swiftc -O "${TARGETFLAGS[@]}" \
      -emit-library -static -emit-module \
      -module-name SwiftTerm \
      -emit-module-path "$TDIR/SwiftTerm.swiftmodule" \
      -o "$TDIR/libSwiftTerm.a" \
      "${VENDOR_FILES[@]}" || return 1
  fi

  echo "  $APP_NAME ($TAG)…"
  swiftc -O -parse-as-library "${TARGETFLAGS[@]}" \
    -I "$TDIR" -L "$TDIR" -lSwiftTerm \
    -o "$TDIR/$APP_NAME" \
    Sources/Shared/*.swift Sources/Platform/*.swift Sources/macOS/*.swift || return 1
}

build_for arm64 2>"$BUILD_DIR/arm64.log" || ARM_FAILED=1
build_for x86_64 2>"$BUILD_DIR/x86_64.log" || X86_FAILED=1

if [[ -n "$ARM_FAILED" && -n "$X86_FAILED" ]]; then
  echo "Both targeted builds failed — compiling for native arch with full errors:"
  build_for ""
  BINARY="$BUILD_DIR/native/$APP_NAME"
elif [[ -z "$ARM_FAILED" && -z "$X86_FAILED" ]]; then
  lipo -create -output "$BUILD_DIR/$APP_NAME" \
    "$BUILD_DIR/arm64/$APP_NAME" "$BUILD_DIR/x86_64/$APP_NAME"
  BINARY="$BUILD_DIR/$APP_NAME"
elif [[ -z "$ARM_FAILED" ]]; then
  BINARY="$BUILD_DIR/arm64/$APP_NAME"
else
  BINARY="$BUILD_DIR/x86_64/$APP_NAME"
fi

echo "Assembling Kitib.app bundle..."
APP="Kitib.app"
rm -rf MD.app Kitish.app   # remove old-name builds if present
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$APP_NAME"
chmod +x "$APP/Contents/MacOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>Kitib</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>© 2026 Sean</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
</dict>
PLIST

# App icon — priority: Assets.xcassets (from Xcode) > icon.png fallback
ICON_SRC=""
APPICONSET=$(find . -maxdepth 3 -type d -name "*.appiconset" 2>/dev/null | head -1)
if [[ -n "$APPICONSET" ]]; then
  # use the largest PNG in the appiconset as the master
  LARGEST=""; LARGEST_W=0
  for PNG in "$APPICONSET"/*.png; do
    [[ -f "$PNG" ]] || continue
    W=$(sips -g pixelWidth "$PNG" 2>/dev/null | awk '/pixelWidth/{print $2}')
    if [[ -n "$W" && "$W" -gt "$LARGEST_W" ]]; then LARGEST="$PNG"; LARGEST_W=$W; fi
  done
  if [[ -n "$LARGEST" ]]; then
    ICON_SRC="$LARGEST"
    echo "Using app icon from $APPICONSET ($(basename "$LARGEST"), ${LARGEST_W}px)"
  fi
fi
[[ -z "$ICON_SRC" && -f icon.png ]] && ICON_SRC="icon.png"

if [[ -n "$ICON_SRC" ]]; then
  ICONSET="$BUILD_DIR/AppIcon.iconset"
  rm -rf "$ICONSET"; mkdir -p "$ICONSET"
  for SZ in 16 32 128 256 512; do
    sips -z $SZ $SZ "$ICON_SRC" --out "$ICONSET/icon_${SZ}x${SZ}.png" >/dev/null
    sips -z $((SZ*2)) $((SZ*2)) "$ICON_SRC" --out "$ICONSET/icon_${SZ}x${SZ}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null || true
fi

# Bundle the offline web assets (Mermaid + KaTeX + fonts) so WebAssets.swift can
# read and inline them at render time with no network access.
if [[ -d "$WEB_DIR" ]]; then
  echo "Bundling offline web assets into app..."
  mkdir -p "$APP/Contents/Resources/web"
  ditto "$WEB_DIR" "$APP/Contents/Resources/web"
  rm -f "$APP/Contents/Resources/web/.ok"
fi

# Bundle license notices so the distributed .app carries the required
# attribution for Kitib (MIT) and its vendored dependencies (SwiftTerm, MIT).
[[ -f LICENSE ]] && cp LICENSE "$APP/Contents/Resources/LICENSE"
[[ -f THIRD-PARTY-LICENSES.txt ]] && cp THIRD-PARTY-LICENSES.txt "$APP/Contents/Resources/THIRD-PARTY-LICENSES.txt"

codesign --force --deep -s - "$APP" 2>/dev/null || true

# ---- Install into /Applications -----------------------------------------------
# Remove every existing Kitib copy first (matched by bundle identifier, so apps
# that merely start with "Kitib" but are something else are left alone), then
# install this fresh build as the single /Applications/Kitib.app. Quit any
# running copy so the bundle can be replaced cleanly.
APPS_DIR="/Applications"
DEST="$APPS_DIR/Kitib.app"

osascript -e 'tell application "Kitib" to quit' >/dev/null 2>&1 || true
sleep 1

echo "Cleaning old Kitib copies in $APPS_DIR ..."
removed=0
shopt -s nullglob
for candidate in "$APPS_DIR"/*.app; do
  plist="$candidate/Contents/Info"
  # Trailing `|| true` keeps a failed read from aborting the script (set -e).
  id="$(defaults read "$plist" CFBundleIdentifier 2>/dev/null || /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist.plist" 2>/dev/null || true)"
  if [[ "$id" == "$BUNDLE_ID" ]]; then
    echo "  removing $(basename "$candidate")"
    rm -rf "$candidate" && removed=$((removed + 1))
  fi
done
shopt -u nullglob
[[ "$removed" -eq 0 ]] && echo "  (none found)"

echo "Installing fresh build to $DEST ..."
if ditto "$APP" "$DEST" 2>/dev/null; then
  rm -rf "$APP"          # keep only the /Applications copy to avoid duplicates
  RUN_APP="$DEST"
else
  echo "  ⚠️  Couldn't write to $APPS_DIR — leaving the build at $APP."
  RUN_APP="$APP"
fi

# Nudge Launch Services / Dock to drop any cached (generic) icon for this path
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[[ -x "$LSREG" ]] && "$LSREG" -f "$RUN_APP" >/dev/null 2>&1 || true
touch "$RUN_APP"

echo ""
echo "✓ Built and installed — run it with: open \"$RUN_APP\""
