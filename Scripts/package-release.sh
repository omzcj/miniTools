#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?Usage: package-release.sh <version>}"
APP_DIR="$ROOT/dist/miniTools.app"
ARCHIVE_NAME="miniTools-$VERSION.zip"
ARCHIVE_PATH="$ROOT/dist/$ARCHIVE_NAME"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
APP_BUILD="${APP_BUILD:-1}" \
    "$ROOT/Scripts/build-universal-app.sh" "$VERSION"

codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -f "$ARCHIVE_PATH" "$CHECKSUM_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE_PATH"
(
    cd "$ROOT/dist"
    shasum -a 256 "$ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"
)

SHA256="$(awk '{ print $1 }' "$CHECKSUM_PATH")"

echo "Release archive: $ARCHIVE_PATH"
echo "SHA-256: $SHA256"
