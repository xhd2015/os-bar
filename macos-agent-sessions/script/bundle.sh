#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="os-bar-agent-sessions"
BUNDLE_DIR="$PROJECT_DIR/$APP_NAME.app"
CONTENTS="$BUNDLE_DIR/Contents"
MACOS_BIN="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "==> Building agent-sessions CLI"
cd "$PROJECT_DIR/go-pkgs/cmd/agent-sessions"
go build -o "$PROJECT_DIR/.build/agent-sessions" .

echo "==> Building $APP_NAME (release)"
cd "$PROJECT_DIR"
swift build -c release

echo "==> Creating .app bundle at $BUNDLE_DIR"
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_BIN" "$RESOURCES"

BIN_PATH="$(swift build -c release --show-bin-path)/$APP_NAME"
cp "$BIN_PATH" "$MACOS_BIN/"
cp "$PROJECT_DIR/.build/agent-sessions" "$MACOS_BIN/agent-sessions"
chmod +x "$MACOS_BIN/agent-sessions"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.os-bar.agent-sessions</string>
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

echo "==> Ad-hoc code signing"
codesign --force --deep -s - "$BUNDLE_DIR" 2>/dev/null || true

echo ""
echo "==> App bundle ready: $BUNDLE_DIR"

if [[ "${BUNDLE_SKIP_DMG:-}" == "1" ]]; then
    echo "    (DMG skipped — set BUNDLE_SKIP_DMG=0 or unset to create $APP_NAME.dmg)"
    exit 0
fi

DMG_PATH="$PROJECT_DIR/$APP_NAME.dmg"
STAGING="$PROJECT_DIR/.dmg-staging"

echo "==> Creating DMG at $DMG_PATH"
rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"

cp -R "$BUNDLE_DIR" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING"

echo ""
echo "==> Done:"
echo "    DMG:  $DMG_PATH"
echo ""
echo "    To install on another machine:"
echo "      1. Copy $APP_NAME.dmg to target machine"
echo "      2. Open the DMG, drag $APP_NAME.app to the Applications folder"
echo "      3. First launch: right-click → Open (Gatekeeper bypass)"
