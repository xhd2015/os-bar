#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="os-bar-agent-sessions"
DMG_PATH="$PROJECT_DIR/$APP_NAME.dmg"

echo "==> Bundling $APP_NAME ..."
"$SCRIPT_DIR/bundle.sh"

echo ""
echo "==> Opening DMG ..."
open "$DMG_PATH"
