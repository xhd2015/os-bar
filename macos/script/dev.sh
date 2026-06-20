#!/usr/bin/env bash
set -euo pipefail

# Determine macos/ directory from the script's own location
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Building os-bar-daemon CLI"
cd "$MACOS_DIR/go-pkgs/cmd/os-bar"
go build -o "$MACOS_DIR/.build/os-bar-daemon" .

echo "==> Building os-bar in $MACOS_DIR"
cd "$MACOS_DIR"
swift build

echo "==> Starting os-bar"
export OS_BAR_CLI="$MACOS_DIR/.build/os-bar-daemon"
swift run os-bar
