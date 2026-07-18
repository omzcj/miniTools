#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?Usage: package-release.sh <version>}"
APP_DIR="$ROOT/dist/miniTools.app"
ARCHIVE_NAME="miniTools-$VERSION.zip"
ARCHIVE_PATH="$ROOT/dist/$ARCHIVE_NAME"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"
NOTARY_ARCHIVE="$ROOT/dist/miniTools-$VERSION.notary.zip"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:?Set CODE_SIGN_IDENTITY to a Developer ID Application identity.}"
APPLE_API_PRIVATE_KEY_PATH="${APPLE_API_PRIVATE_KEY_PATH:?Set APPLE_API_PRIVATE_KEY_PATH.}"
APPLE_API_KEY_ID="${APPLE_API_KEY_ID:?Set APPLE_API_KEY_ID.}"
APPLE_API_ISSUER_ID="${APPLE_API_ISSUER_ID:?Set APPLE_API_ISSUER_ID.}"

if [[ "$SIGN_IDENTITY" != "Developer ID Application:"* ]]; then
    echo "Public releases require a Developer ID Application identity." >&2
    exit 1
fi
if [[ ! -f "$APPLE_API_PRIVATE_KEY_PATH" ]]; then
    echo "Notary API private key not found: $APPLE_API_PRIVATE_KEY_PATH" >&2
    exit 1
fi

CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
APP_BUILD="${APP_BUILD:-1}" \
    "$ROOT/Scripts/build-universal-app.sh" "$VERSION"

rm -f "$NOTARY_ARCHIVE" "$ARCHIVE_PATH" "$CHECKSUM_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$NOTARY_ARCHIVE"

xcrun notarytool submit "$NOTARY_ARCHIVE" \
    --key "$APPLE_API_PRIVATE_KEY_PATH" \
    --key-id "$APPLE_API_KEY_ID" \
    --issuer "$APPLE_API_ISSUER_ID" \
    --wait

xcrun stapler staple "$APP_DIR"
xcrun stapler validate "$APP_DIR"
spctl --assess --type execute --verbose=4 "$APP_DIR"

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE_PATH"
(
    cd "$ROOT/dist"
    shasum -a 256 "$ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"
)

SHA256="$(awk '{ print $1 }' "$CHECKSUM_PATH")"
"$ROOT/Scripts/render-homebrew-cask.sh" "$VERSION" "$SHA256"
rm -f "$NOTARY_ARCHIVE"

echo "Release archive: $ARCHIVE_PATH"
echo "SHA-256: $SHA256"
