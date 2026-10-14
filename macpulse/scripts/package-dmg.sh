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
MACAPP_ENTITLEMENTS="$PWD/Sources/MacPulseWidget/Widget.entitlements" bash ../scripts/sign-bundle.sh "$widget"
# Verify signing did not strip the sandbox or scoped snapshot read entitlement.
codesign -d --entitlements :- "$widget" > "$PWD/build/widget-entitlements.plist" 2>/dev/null
/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$PWD/build/widget-entitlements.plist" | /usr/bin/grep -qx true
/usr/libexec/PlistBuddy -c 'Print :com.apple.security.temporary-exception.files.home-relative-path.read-only:0' "$PWD/build/widget-entitlements.plist" | /usr/bin/grep -qx '/Library/Application Support/com.sujanmj.macpulse/'
# The updater helper runs after MacPulse quits. Sign it before signing the
# outer app bundle so the signature seal includes the helper.
xcrun swiftc -swift-version 5 -target arm64-apple-macos14.0 \
  -O -parse-as-library \
  -o "$app/Contents/MacOS/MacAppInstallHelper" \
  ../scripts/MacAppInstallHelper.swift
if [[ "${MACAPP_SIGNING_IDENTITY:--}" == "-" ]]; then
  codesign --force --sign - --timestamp=none "$app/Contents/MacOS/MacAppInstallHelper"
else
  codesign --force --options runtime --timestamp --sign "$MACAPP_SIGNING_IDENTITY" "$app/Contents/MacOS/MacAppInstallHelper"
fi
MACAPP_ENTITLEMENTS="$PWD/Sources/MacPulse/MacPulse.entitlements" bash ../scripts/sign-bundle.sh "$app"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/MacPulse.app"
ln -s /Applications "$stage/Applications"
codesign --verify --deep --strict --verbose=2 "$stage/MacPulse.app"
dmg="$PWD/MacPulse-v1.1.dmg"
hdiutil create -volname MacPulse -srcfolder "$stage" -ov -format UDZO "$dmg"
hdiutil verify "$dmg"
bash ../scripts/notarize-dmg.sh "$dmg"
shasum -a 256 "$(basename "$dmg")" > "$dmg.sha256"
echo "Installer created: $dmg"
