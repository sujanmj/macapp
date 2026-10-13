#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || { echo "Install xcodegen: brew install xcodegen"; exit 1; }
xcodegen generate
xcodebuild -project MacMotion.xcodeproj -scheme MacMotion -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath "$PWD/build" CODE_SIGNING_ALLOWED=NO build
app="$PWD/build/Build/Products/Release/MacMotion.app"
test -d "$app" || { echo "App was not built"; exit 1; }
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/MacMotion.app"
ln -s /Applications "$stage/Applications"
hdiutil create -volname "MacMotion" -srcfolder "$stage" -ov -format UDZO "$PWD/MacMotion-v1.1.dmg"
hdiutil verify "$PWD/MacMotion-v1.1.dmg"
echo "DMG ready: $PWD/MacMotion-v1.1.dmg"
