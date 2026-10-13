# macapp — free native macOS utilities

Two independent macOS apps, each with its own XcodeGen project and source tree:

| App | Description | Build |
| --- | --- | --- |
| [MacMotion](macmotion/) | MP4/MOV live desktop wallpaper menu-bar app | `cd macmotion && xcodegen generate && open MacMotion.xcodeproj` |
| [LumaFlow](lumaflow/) | Experimental content-aware built-in display auto brightness, inspired by Rubarb | `cd lumaflow && xcodegen generate && open LumaFlow.xcodeproj` |

Requires macOS 14+, Xcode, and `brew install xcodegen`.

**Packaging:** `bash macmotion/scripts/package-dmg.sh` or `bash lumaflow/scripts/package-dmg.sh`.

**Releases:** GitHub Actions builds both installers independently. `MacMotion-v1.1.dmg` has been built locally; LumaFlow is an unverified prototype.

**Privacy:** LumaFlow requests Screen Recording access only when the user enables screen luminance analysis; it does not store or upload captures.

Both apps are independent projects, not copies of the upstream inspiration. MIT licensed.
