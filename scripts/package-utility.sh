#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in MacShelf|MacSwitch|MacNotch|MacVoice) name="$1" ;; *) echo 'Choose MacShelf, MacSwitch, MacNotch or MacVoice' >&2; exit 2 ;; esac
repo="$(cd "$(dirname "$0")/.." && pwd)"
folder="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
cd "$repo/$folder"
mkdir -p build/IconModuleCache
xcrun swift -module-cache-path "$PWD/build/IconModuleCache" ../scripts/generate-utility-icons.swift "$name" Assets.xcassets/AppIcon.appiconset
xcodegen generate
xcodebuild -project "$name.xcodeproj" -scheme "$name" -configuration Release \
  -destination 'platform=macOS' -derivedDataPath "$PWD/build" \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
app="$PWD/build/Build/Products/Release/$name.app"
test -d "$app"
MACAPP_ENTITLEMENTS="$PWD/Sources/$name/$name.entitlements" bash ../scripts/sign-bundle.sh "$app"
codesign -d --entitlements :- "$app" > build/signed-entitlements.plist 2>/dev/null
case "$name" in
  MacVoice)
    /usr/libexec/PlistBuddy -c 'Print :com.apple.security.device.audio-input' build/signed-entitlements.plist | /usr/bin/grep -qx true
    /usr/libexec/PlistBuddy -c 'Print :com.apple.security.personal-information.speech-recognition' build/signed-entitlements.plist | /usr/bin/grep -qx true ;;
  MacNotch) /usr/libexec/PlistBuddy -c 'Print :com.apple.security.automation.apple-events' build/signed-entitlements.plist | /usr/bin/grep -qx true ;;
esac
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/$name.app"
ln -s /Applications "$stage/Applications"
codesign --verify --deep --strict --verbose=2 "$stage/$name.app"
lipo -verify_arch arm64 x86_64 "$app/Contents/MacOS/$name"
dmg="$PWD/$name-v0.1.dmg"
hdiutil create -volname "$name" -srcfolder "$stage" -ov -format UDZO "$dmg"
hdiutil verify "$dmg"
bash ../scripts/notarize-dmg.sh "$dmg"
shasum -a 256 "$(basename "$dmg")" > "$dmg.sha256"
echo "Verified installer: $dmg"
