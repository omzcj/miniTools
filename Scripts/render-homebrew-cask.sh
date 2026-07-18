#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?Usage: render-homebrew-cask.sh <version> <sha256> [output-path]}"
SHA256="${2:?Usage: render-homebrew-cask.sh <version> <sha256> [output-path]}"
OUTPUT_PATH="${3:-"$ROOT/dist/minitools.rb"}"
TEMPLATE="$ROOT/Packaging/Homebrew/minitools.rb.template"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Version must use X.Y.Z format: $VERSION" >&2
    exit 1
fi
if [[ ! "$SHA256" =~ ^[0-9a-f]{64}$ ]]; then
    echo "SHA-256 must contain 64 lowercase hexadecimal characters." >&2
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"
sed \
    -e "s/__VERSION__/$VERSION/g" \
    -e "s/__SHA256__/$SHA256/g" \
    "$TEMPLATE" > "$OUTPUT_PATH"

echo "Rendered $OUTPUT_PATH"
