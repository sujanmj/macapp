#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v rsvg-convert >/dev/null || { echo "brew install librsvg"; exit 1; }
mkdir -p Assets.xcassets/AppIcon.appiconset
for size in 16 32 64 128 256 512 1024; do
  rsvg-convert -w "$size" -h "$size" Artwork/AppIcon.svg > "Assets.xcassets/AppIcon.appiconset/icon-$size.png"
done
