#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
name="MacMotionScreenSaver"
bundle="$PWD/build/saver/MacMotion.saver"
rm -rf "$bundle"
mkdir -p "$bundle/Contents/MacOS"
cp Sources/ScreenSaver/Info.plist "$bundle/Contents/Info.plist"
xcrun swiftc -swift-version 5 \
  -module-name "$name" \
  -target arm64-apple-macos14.0 \
  -O -parse-as-library -emit-library \
  -framework AppKit -framework ScreenSaver -framework AVFoundation -framework QuartzCore \
  -o "$bundle/Contents/MacOS/$name" \
  Sources/ScreenSaver/MacMotionScreenSaverView.swift
codesign --force --sign - --timestamp=none "$bundle"
echo "Built screen saver: $bundle"
