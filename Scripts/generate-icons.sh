#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSET_DIR="$ROOT/Support/Assets"
BUILD_DIR="$ROOT/.build/icon-assets"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
MASTER_ICON="$BUILD_DIR/AppIcon-1024.png"

command -v rsvg-convert >/dev/null
command -v iconutil >/dev/null

rm -rf "$BUILD_DIR"
mkdir -p "$ICONSET_DIR"

rsvg-convert -w 1024 -h 1024 "$ASSET_DIR/SmartisanAppIcon.svg" -o "$MASTER_ICON"

render_icon() {
    local size="$1"
    local filename="$2"
    sips -z "$size" "$size" "$MASTER_ICON" --out "$ICONSET_DIR/$filename" >/dev/null
}

render_icon 16 icon_16x16.png
render_icon 32 icon_16x16@2x.png
render_icon 32 icon_32x32.png
render_icon 64 icon_32x32@2x.png
render_icon 128 icon_128x128.png
render_icon 256 icon_128x128@2x.png
render_icon 256 icon_256x256.png
render_icon 512 icon_256x256@2x.png
render_icon 512 icon_512x512.png
render_icon 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET_DIR" -o "$ASSET_DIR/AppIcon.icns"
rsvg-convert -w 64 -h 64 "$ASSET_DIR/SmartisanStatusIcon.svg" \
    -o "$ASSET_DIR/SmartisanStatusIcon.png"

echo "Generated $ASSET_DIR/AppIcon.icns"
echo "Generated $ASSET_DIR/SmartisanStatusIcon.png"
