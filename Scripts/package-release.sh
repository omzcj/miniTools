#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?Usage: package-release.sh <release-version>}"
if [[ ! "$VERSION" =~ ^([0-9]{4}\.[0-9]{2}\.[0-9]{2})\.[1-9][0-9]*$ ]]; then
    echo "Release version must use YYYY.MM.DD.N format: $VERSION" >&2
    exit 1
fi
APP_VERSION="${APP_VERSION:-${BASH_REMATCH[1]}}"
APP_DIR="$ROOT/dist/release/miniTools.app"
ARCHIVE_NAME="miniTools-$VERSION.zip"
ARCHIVE_PATH="$ROOT/dist/$ARCHIVE_NAME"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
APP_VERSION="$APP_VERSION" \
APP_BUILD="${APP_BUILD:-1}" \
APP_OUTPUT_PATH="$APP_DIR" \
    "$ROOT/Scripts/build-universal-app.sh" "$APP_VERSION"

codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -f "$ARCHIVE_PATH" "$CHECKSUM_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE_PATH"
(
    cd "$ROOT/dist"
    shasum -a 256 "$ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"
)

SHA256="$(awk '{ print $1 }' "$CHECKSUM_PATH")"

echo "Release archive: $ARCHIVE_PATH"
echo "App version: $APP_VERSION"
echo "SHA-256: $SHA256"
