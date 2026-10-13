#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
xcodebuild -project LumaFlow.xcodeproj -scheme LumaFlow -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath "$PWD/build" CODE_SIGNING_ALLOWED=NO build
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
ditto build/Build/Products/Release/LumaFlow.app "$stage/LumaFlow.app"
ln -s /Applications "$stage/Applications"
hdiutil create -volname LumaFlow -srcfolder "$stage" -ov -format UDZO "$PWD/LumaFlow-v0.1.dmg"
hdiutil verify "$PWD/LumaFlow-v0.1.dmg"
