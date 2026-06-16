#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Building os-bar-agent-sessions in $PROJECT_DIR"
cd "$PROJECT_DIR"
swift build

echo "==> Starting os-bar-agent-sessions"
swift run os-bar-agent-sessions
