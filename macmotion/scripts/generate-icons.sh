#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v rsvg-convert >/dev/null; then
  echo "Install SVG renderer: brew install librsvg" >&2
  exit 1
fi
mkdir -p Assets.xcassets/AppIcon.appiconset
for size in 16 32 64 128 256 512 1024; do
  rsvg-convert -w "$size" -h "$size" Artwork/AppIcon.svg \
    > "Assets.xcassets/AppIcon.appiconset/icon-$size.png"
done
