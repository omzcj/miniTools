#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="miniTools"
EXECUTABLE_NAME="MiniTools"
APP_DIR="$ROOT/dist/$APP_NAME.app"

"$ROOT/Scripts/build-app.sh" debug

if pgrep -x "$EXECUTABLE_NAME" >/dev/null; then
    if ! pkill -x "$EXECUTABLE_NAME"; then
        echo "miniTools exited before it could be restarted."
    fi
fi

open -n "$APP_DIR"
