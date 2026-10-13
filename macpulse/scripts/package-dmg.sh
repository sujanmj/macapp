#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/generate-icons.sh
xcodegen generate
xcodebuild -project MacPulse.xcodeproj -scheme MacPulse \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$PWD/build" CODE_SIGNING_ALLOWED=NO build
app="$PWD/build/Build/Products/Release/MacPulse.app"
test -d "$app" || { echo "App build missing"; exit 1; }
widget="$app/Contents/PlugIns/MacPulseWidget.appex"
test -d "$widget" || { echo "Widget extension was not embedded"; exit 1; }
bash ../scripts/sign-bundle.sh "$widget"
bash ../scripts/sign-bundle.sh "$app"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/MacPulse.app"
ln -s /Applications "$stage/Applications"
codesign --verify --deep --strict --verbose=2 "$stage/MacPulse.app"
dmg="$PWD/MacPulse-v0.7.dmg"
hdiutil create -volname MacPulse -srcfolder "$stage" -ov -format UDZO "$dmg"
hdiutil verify "$dmg"
bash ../scripts/notarize-dmg.sh "$dmg"
shasum -a 256 "$(basename "$dmg")" > "$dmg.sha256"
echo "Installer created: $dmg"
