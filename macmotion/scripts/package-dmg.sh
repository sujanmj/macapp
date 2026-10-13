#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || { echo "Install xcodegen: brew install xcodegen"; exit 1; }
bash scripts/generate-icons.sh
xcodegen generate
xcodebuild \
  -project MacMotion.xcodeproj -scheme MacMotion \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$PWD/build" CODE_SIGNING_ALLOWED=NO build
app="$PWD/build/Build/Products/Release/MacMotion.app"
test -d "$app" || { echo "App was not built"; exit 1; }
bash scripts/build-screen-saver.sh
saver="$PWD/build/saver/MacMotion.saver"
# Embed the signed screen saver FIRST, then sign the complete app LAST.
mkdir -p "$app/Contents/Resources"
rm -rf "$app/Contents/Resources/MacMotion.saver"
ditto "$saver" "$app/Contents/Resources/MacMotion.saver"
bash ../scripts/sign-bundle.sh "$app"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/MacMotion.app"
ditto "$saver" "$stage/MacMotion.saver"
ln -s /Applications "$stage/Applications"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$stage/MacMotion.app"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$stage/MacMotion.saver"
dmg="$PWD/MacMotion-v1.5.dmg"
hdiutil create -volname "MacMotion" -srcfolder "$stage" -ov -format UDZO "$dmg"
hdiutil verify "$dmg"
bash ../scripts/notarize-dmg.sh "$dmg"
shasum -a 256 "$dmg" > "$dmg.sha256"
echo "DMG ready: $dmg"
