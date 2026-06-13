#!/bin/bash
# Builds Kitib.app — a minimalist focused-writing app for macOS.
# Requires: Xcode Command Line Tools (xcode-select --install)
# Usage: ./build.sh   → produces ./Kitib.app

set -e
cd "$(dirname "$0")"

APP_NAME="Kitib"
BUNDLE_ID="com.sean.kitib"
BUILD_DIR=".build-app"

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
    Sources/*.swift || return 1
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

# Bundle license notices so the distributed .app carries the required
# attribution for Kitib (MIT) and its vendored dependencies (SwiftTerm, MIT).
[[ -f LICENSE ]] && cp LICENSE "$APP/Contents/Resources/LICENSE"
[[ -f THIRD-PARTY-LICENSES.txt ]] && cp THIRD-PARTY-LICENSES.txt "$APP/Contents/Resources/THIRD-PARTY-LICENSES.txt"

codesign --force --deep -s - "$APP" 2>/dev/null || true

# Nudge Launch Services / Dock to drop any cached (generic) icon for this path
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[[ -x "$LSREG" ]] && "$LSREG" -f "$APP" >/dev/null 2>&1 || true
touch "$APP"

echo ""
echo "✓ Built $APP — double-click it or run: open $APP"
echo "  Note: if Kitib is running, quit it first, then reopen."
echo "  (Optional) move it to /Applications: mv $APP /Applications/"
