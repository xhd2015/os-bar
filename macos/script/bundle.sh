#!/usr/bin/env bash
set -euo pipefail

# Determine macos/ directory from the script's own location
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="os-bar"
BUNDLE_DIR="$MACOS_DIR/$APP_NAME.app"
CONTENTS="$BUNDLE_DIR/Contents"
MACOS_BIN="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "==> Building os-bar-daemon CLI"
cd "$MACOS_DIR/go-pkgs/cmd/os-bar"
go build -o "$MACOS_DIR/.build/os-bar-daemon" .

echo "==> Building $APP_NAME (release)"
cd "$MACOS_DIR"
swift build -c release

echo "==> Creating .app bundle at $BUNDLE_DIR"
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_BIN" "$RESOURCES"

# Copy binary (architecture-agnostic)
BIN_PATH="$(swift build -c release --show-bin-path)/$APP_NAME"
cp "$BIN_PATH" "$MACOS_BIN/"
cp "$MACOS_DIR/.build/os-bar-daemon" "$MACOS_BIN/os-bar-daemon"
chmod +x "$MACOS_BIN/os-bar-daemon"

# Create Info.plist
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.os-bar.app</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc sign so Gatekeeper doesn't block on same machine
echo "==> Ad-hoc code signing"
codesign --force --deep -s - "$BUNDLE_DIR" 2>/dev/null || true

echo ""
echo "==> App bundle ready: $BUNDLE_DIR"

if [[ "${BUNDLE_SKIP_DMG:-}" == "1" ]]; then
    echo "    (DMG skipped — set BUNDLE_SKIP_DMG=0 or unset to create os-bar.dmg)"
    exit 0
fi

# Package for distribution
DMG_PATH="$MACOS_DIR/$APP_NAME.dmg"
STAGING="$MACOS_DIR/.dmg-staging"

echo "==> Creating DMG at $DMG_PATH"
rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"

# Copy .app and create Applications symlink (standard DMG layout)
cp -R "$BUNDLE_DIR" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Create compressed read-only DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING"

echo ""
echo "==> Done:"
echo "    App:  $BUNDLE_DIR"
echo "    DMG:  $DMG_PATH"
echo ""
echo "    To install on this machine without dragging:"
echo "      ./script/install.sh"
echo ""
echo "    To install on another machine:"
echo "      1. Copy os-bar.dmg to target machine"
echo "      2. Open the DMG, drag os-bar.app to the Applications folder"
echo "      3. First launch: right-click → Open (Gatekeeper bypass)"
