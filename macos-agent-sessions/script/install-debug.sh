#!/usr/bin/env bash
set -euo pipefail

# Debug variant of install.sh — isolated bundle ID for notification/UI tests.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: $(basename "$0") [options]

Build os-bar-agent-sessions-debug.app (debug Swift + AGENT_SESSIONS_DEBUG) and
install to /Applications. Delegates to install.sh with debug env overrides.

Bundle ID: com.os-bar.agent-sessions.debug — grant Notifications separately
from the production app.

Options: same as install.sh (--no-open, --open, --install-root, -h, --help)

Examples:
  ./script/install-debug.sh --no-open
  notification-click-ui tests use this app automatically (no USE_INSTALLED_APP).
EOF
    exit 0
fi

export APP_NAME="os-bar-agent-sessions-debug"
export BUNDLE_ID="com.os-bar.agent-sessions.debug"
export SWIFT_BUILD_CONFIG="debug"
export INSTALL_VARIANT="debug"

exec "$SCRIPT_DIR/install.sh" "$@"