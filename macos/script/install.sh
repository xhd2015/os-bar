#!/usr/bin/env bash
set -euo pipefail

# Build os-bar.app and install to /Applications (no drag-and-drop).
# Same end result as Homebrew cask for a standard .app: copy into
# /Applications and clear the quarantine extended attribute.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="os-bar"
SOURCE_APP="$MACOS_DIR/$APP_NAME.app"
INSTALL_ROOT="${INSTALL_ROOT:-/Applications}"
TARGET_APP="$INSTALL_ROOT/$APP_NAME.app"
OPEN_AFTER_INSTALL=0

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Build os-bar.app (via bundle.sh) and install to $INSTALL_ROOT.

Options:
  --open          Launch os-bar after install
  --install-root  Override install directory (default: /Applications)
  -h, --help      Show this help

Examples:
  ./script/install.sh
  ./script/install.sh --open
  INSTALL_ROOT=\$HOME/Applications ./script/install.sh
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --open)
            OPEN_AFTER_INSTALL=1
            shift
            ;;
        --install-root)
            INSTALL_ROOT="$2"
            TARGET_APP="$INSTALL_ROOT/$APP_NAME.app"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ ! -w "$INSTALL_ROOT" ]]; then
    echo "error: cannot write to $INSTALL_ROOT (try sudo or set INSTALL_ROOT)" >&2
    exit 1
fi

echo "==> Building $APP_NAME.app"
BUNDLE_SKIP_DMG=1 "$SCRIPT_DIR/bundle.sh"

if [[ ! -d "$SOURCE_APP" ]]; then
    echo "error: expected app bundle at $SOURCE_APP" >&2
    exit 1
fi

echo "==> Stopping running $APP_NAME (if any)"
osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || true
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.5

echo "==> Installing to $TARGET_APP"
rm -rf "$TARGET_APP"
ditto "$SOURCE_APP" "$TARGET_APP"
xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true

echo ""
echo "==> Installed: $TARGET_APP"
echo "    First launch from a downloaded build may still need right-click → Open."
echo "    Local ad-hoc builds from this machine usually launch normally."

if [[ "$OPEN_AFTER_INSTALL" -eq 1 ]]; then
    echo "==> Opening $APP_NAME"
    open "$TARGET_APP"
fi