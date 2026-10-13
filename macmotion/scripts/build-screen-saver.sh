#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
name="MacMotionScreenSaver"
bundle="$PWD/build/saver/MacMotion.saver"
bash scripts/generate-icons.sh
rm -rf "$bundle"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp Sources/ScreenSaver/Info.plist "$bundle/Contents/Info.plist"

# Preview tile for System Settings → Wallpaper → Screen Saver…
rsvg-convert -w 256 -h 160 Artwork/ScreenSaverThumbnail.svg \
  > "$bundle/Contents/Resources/thumbnail.png"
rsvg-convert -w 512 -h 320 Artwork/ScreenSaverThumbnail.svg \
  > "$bundle/Contents/Resources/thumbnail@2x.png"

# Regular Finder / Spotlight bundle icon for the .saver package.
iconset="$PWD/build/saver/MacMotion.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  cp "Assets.xcassets/AppIcon.appiconset/icon-$size.png" "$iconset/icon_${size}x${size}.png"
  double=$((size * 2))
  cp "Assets.xcassets/AppIcon.appiconset/icon-$double.png" "$iconset/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$iconset" -o "$bundle/Contents/Resources/MacMotion.icns"
xcrun swiftc -swift-version 5 \
  -module-name "$name" \
  -target arm64-apple-macos14.0 \
  -O -parse-as-library -emit-library \
  -framework AppKit -framework ScreenSaver -framework AVFoundation -framework QuartzCore \
  -o "$bundle/Contents/MacOS/$name" \
  Sources/ScreenSaver/MacMotionScreenSaverView.swift
codesign --force --sign - --timestamp=none "$bundle"
echo "Built screen saver with icon: $bundle"
