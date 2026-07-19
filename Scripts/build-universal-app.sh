#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?Usage: build-universal-app.sh <version>}"
EXECUTABLE_NAME="MiniTools"
APP_DIR="${APP_OUTPUT_PATH:-"$ROOT/dist/miniTools.app"}"
ARM_BUILD_DIR="$ROOT/.build/release-arm64"
INTEL_BUILD_DIR="$ROOT/.build/release-x86_64"
UNIVERSAL_DIR="$ROOT/.build/release-universal"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:?Set CODE_SIGN_IDENTITY to a code-signing identity.}"

if [[ ! "$VERSION" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}$ ]]; then
    echo "App version must use YYYY.MM.DD format: $VERSION" >&2
    exit 1
fi
PARSED_VERSION="$(/bin/date -j -f '%Y.%m.%d' \
    "$VERSION" '+%Y.%m.%d' 2>/dev/null || true)"
if [[ "$PARSED_VERSION" != "$VERSION" ]]; then
    echo "App version contains an invalid calendar date: $VERSION" >&2
    exit 1
fi

cd "$ROOT"
swift build \
    -c release \
    --triple arm64-apple-macosx26.0 \
    --scratch-path "$ARM_BUILD_DIR"
swift build \
    -c release \
    --triple x86_64-apple-macosx26.0 \
    --scratch-path "$INTEL_BUILD_DIR"

mkdir -p "$UNIVERSAL_DIR"
lipo -create \
    "$ARM_BUILD_DIR/arm64-apple-macosx/release/$EXECUTABLE_NAME" \
    "$INTEL_BUILD_DIR/x86_64-apple-macosx/release/$EXECUTABLE_NAME" \
    -output "$UNIVERSAL_DIR/$EXECUTABLE_NAME"

ARCHITECTURES="$(lipo -archs "$UNIVERSAL_DIR/$EXECUTABLE_NAME")"
if [[ "$ARCHITECTURES" != *"arm64"* || "$ARCHITECTURES" != *"x86_64"* ]]; then
    echo "Universal executable is missing an architecture: $ARCHITECTURES" >&2
    exit 1
fi

APP_VERSION="$VERSION" \
APP_BUILD="${APP_BUILD:-1}" \
CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    "$ROOT/Scripts/assemble-app.sh" "$UNIVERSAL_DIR/$EXECUTABLE_NAME" "$APP_DIR"

echo "Architectures: $ARCHITECTURES"
