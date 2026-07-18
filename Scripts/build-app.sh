#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="miniTools"
EXECUTABLE_NAME="MiniTools"
BUILD_CONFIGURATION="${1:-${BUILD_CONFIGURATION:-release}}"
BUILD_DIR="$ROOT/.build/$BUILD_CONFIGURATION"
APP_DIR="$ROOT/dist/$APP_NAME.app"

case "$BUILD_CONFIGURATION" in
    debug|release) ;;
    *)
        echo "Unsupported build configuration: $BUILD_CONFIGURATION" >&2
        echo "Use debug or release." >&2
        exit 1
        ;;
esac

resolve_signing_identity() {
    if [[ "${CODE_SIGN_IDENTITY:-}" == "-" ]]; then
        echo "Ad-hoc signing is disabled because it invalidates Accessibility permissions after rebuilds." >&2
        exit 1
    fi

    if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
        printf '%s\n' "$CODE_SIGN_IDENTITY"
        return
    fi

    local identities
    local preferred_identities
    local preferred_count
    local apple_development_identities
    local apple_development_count

    identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"
    preferred_identities="$(
        printf '%s\n' "$identities" |
            awk -F '"' '$2 ~ /^Apple Development:/ && $2 !~ /Created via API/ { print $2 }'
    )"
    preferred_count="$(printf '%s\n' "$preferred_identities" | sed '/^$/d' | wc -l | tr -d ' ')"

    if [[ "$preferred_count" == "1" ]]; then
        printf '%s\n' "$preferred_identities"
        return
    fi

    apple_development_identities="$(
        printf '%s\n' "$identities" |
            awk -F '"' '$2 ~ /^Apple Development:/ { print $2 }'
    )"
    apple_development_count="$(
        printf '%s\n' "$apple_development_identities" | sed '/^$/d' | wc -l | tr -d ' '
    )"

    if [[ "$apple_development_count" == "1" ]]; then
        printf '%s\n' "$apple_development_identities"
        return
    fi

    echo "Unable to choose one stable code-signing identity." >&2
    echo "Set CODE_SIGN_IDENTITY to one identity shown below:" >&2
    security find-identity -v -p codesigning >&2
    exit 1
}

SIGN_IDENTITY="$(resolve_signing_identity)"

cd "$ROOT"
swift build -c "$BUILD_CONFIGURATION"

CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    "$ROOT/Scripts/assemble-app.sh" "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_DIR"
echo "Configuration: $BUILD_CONFIGURATION"
