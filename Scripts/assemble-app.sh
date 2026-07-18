#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="miniTools"
EXECUTABLE_NAME="MiniTools"
EXECUTABLE_PATH="${1:?Usage: assemble-app.sh <executable-path> [app-path]}"
APP_DIR="${2:-"$ROOT/dist/$APP_NAME.app"}"
CONTENTS_DIR="$APP_DIR/Contents"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:?Set CODE_SIGN_IDENTITY to a code-signing identity.}"
APP_VERSION="${APP_VERSION:-"$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT/Support/Info.plist")"}"
APP_BUILD="${APP_BUILD:-"$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$ROOT/Support/Info.plist")"}"

if [[ ! -f "$EXECUTABLE_PATH" ]]; then
    echo "Executable not found: $EXECUTABLE_PATH" >&2
    exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$EXECUTABLE_PATH" "$CONTENTS_DIR/MacOS/$EXECUTABLE_NAME"
cp "$ROOT/Support/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT/Support/Assets/AppIcon.icns" "$CONTENTS_DIR/Resources/AppIcon.icns"
cp "$ROOT/Support/Assets/SmartisanStatusIcon.png" \
    "$CONTENTS_DIR/Resources/SmartisanStatusIcon.png"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$CONTENTS_DIR/Resources/THIRD_PARTY_NOTICES.md"

/usr/libexec/PlistBuddy \
    -c "Set :CFBundleShortVersionString $APP_VERSION" \
    "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy \
    -c "Set :CFBundleVersion $APP_BUILD" \
    "$CONTENTS_DIR/Info.plist"

SIGN_ARGUMENTS=(--force --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" == "Developer ID Application:"* ]]; then
    SIGN_ARGUMENTS+=(--options runtime --timestamp)
fi

codesign "${SIGN_ARGUMENTS[@]}" "$APP_DIR"
codesign --verify --strict "$APP_DIR"

DESIGNATED_REQUIREMENT="$(codesign -d -r- "$APP_DIR" 2>&1)"
if [[ "$DESIGNATED_REQUIREMENT" == *"designated => cdhash"* ]]; then
    echo "The built app has a hash-only identity; refusing an unstable build." >&2
    exit 1
fi

echo "Built $APP_DIR"
echo "Version $APP_VERSION ($APP_BUILD)"
echo "Signed with $SIGN_IDENTITY"
