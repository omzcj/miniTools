#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?Usage: notarize-release.sh <release-version>}"
if [[ ! "$VERSION" =~ ^([0-9]{4}\.[0-9]{2}\.[0-9]{2})\.[1-9][0-9]*$ ]]; then
    echo "Release version must use YYYY.MM.DD.N format: $VERSION" >&2
    exit 1
fi

APP_DIR="$ROOT/dist/release/miniTools.app"
ARCHIVE_NAME="miniTools-$VERSION.zip"
ARCHIVE_PATH="$ROOT/dist/$ARCHIVE_NAME"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"
NOTARY_KEY_PATH="${NOTARY_KEY_PATH:?Set NOTARY_KEY_PATH to an App Store Connect API key.}"
NOTARY_KEY_ID="${NOTARY_KEY_ID:?Set NOTARY_KEY_ID.}"
NOTARY_ISSUER_ID="${NOTARY_ISSUER_ID:?Set NOTARY_ISSUER_ID.}"
EXPECTED_TEAM_ID="${EXPECTED_TEAM_ID:-}"

if [[ ! -d "$APP_DIR" ]]; then
    echo "Release app not found: $APP_DIR" >&2
    exit 1
fi
if [[ ! -f "$ARCHIVE_PATH" ]]; then
    echo "Release archive not found: $ARCHIVE_PATH" >&2
    exit 1
fi
if [[ ! -f "$NOTARY_KEY_PATH" ]]; then
    echo "Notary API key not found: $NOTARY_KEY_PATH" >&2
    exit 1
fi

SIGNATURE_INFO="$(codesign -dvv "$APP_DIR" 2>&1)"
if [[ "$SIGNATURE_INFO" != *"Authority=Developer ID Application:"* ]]; then
    echo "Release app is not signed with Developer ID Application." >&2
    exit 1
fi
if [[ -n "$EXPECTED_TEAM_ID" && "$SIGNATURE_INFO" != *"TeamIdentifier=$EXPECTED_TEAM_ID"* ]]; then
    echo "Release app is not signed by expected team $EXPECTED_TEAM_ID." >&2
    exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_DIR"

xcrun notarytool submit "$ARCHIVE_PATH" \
    --key "$NOTARY_KEY_PATH" \
    --key-id "$NOTARY_KEY_ID" \
    --issuer "$NOTARY_ISSUER_ID" \
    --wait \
    --timeout "${NOTARY_TIMEOUT:-30m}"

xcrun stapler staple "$APP_DIR"
xcrun stapler validate "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
spctl --assess --type execute --verbose=4 "$APP_DIR"

rm -f "$ARCHIVE_PATH" "$CHECKSUM_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE_PATH"
(
    cd "$ROOT/dist"
    shasum -a 256 "$ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"
)

SHA256="$(awk '{ print $1 }' "$CHECKSUM_PATH")"

echo "Notarized release archive: $ARCHIVE_PATH"
echo "SHA-256: $SHA256"
