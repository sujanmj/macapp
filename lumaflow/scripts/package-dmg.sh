#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/generate-icons.sh
xcodegen generate
xcodebuild -project LumaFlow.xcodeproj -scheme LumaFlow \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$PWD/build" CODE_SIGNING_ALLOWED=NO build
app="$PWD/build/Build/Products/Release/LumaFlow.app"
test -d "$app" || { echo "App was not built"; exit 1; }
# Include the post-quit updater helper inside the signed application.
xcrun swiftc -swift-version 5 -target arm64-apple-macos14.0 \
  -O -parse-as-library \
  -o "$app/Contents/MacOS/MacAppInstallHelper" \
  ../scripts/MacAppInstallHelper.swift
if [[ "${MACAPP_SIGNING_IDENTITY:--}" == "-" ]]; then
  codesign --force --sign - --timestamp=none "$app/Contents/MacOS/MacAppInstallHelper"
else
  codesign --force --options runtime --timestamp --sign "$MACAPP_SIGNING_IDENTITY" "$app/Contents/MacOS/MacAppInstallHelper"
fi
bash ../scripts/sign-bundle.sh "$app"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/LumaFlow.app"
ln -s /Applications "$stage/Applications"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$stage/LumaFlow.app"
dmg="$PWD/LumaFlow-v0.5.dmg"
hdiutil create -volname LumaFlow -srcfolder "$stage" -ov -format UDZO "$dmg"
hdiutil verify "$dmg"
bash ../scripts/notarize-dmg.sh "$dmg"
shasum -a 256 "$(basename "$dmg")" > "$dmg.sha256"
echo "DMG ready: $dmg"
