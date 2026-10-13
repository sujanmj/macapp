# macapp — free native macOS utilities

Two independent macOS apps, each with its own XcodeGen project and source tree:

| App | Description | Build |
| --- | --- | --- |
| [MacMotion](macmotion/) | MP4/MOV live desktop wallpaper menu-bar app | `cd macmotion && xcodegen generate && open MacMotion.xcodeproj` |
| [LumaFlow](lumaflow/) | Experimental content-aware built-in display auto brightness, inspired by Rubarb | `cd lumaflow && xcodegen generate && open LumaFlow.xcodeproj` |

Requires macOS 14+, Xcode, and `brew install xcodegen librsvg`.

**Packaging:** `bash macmotion/scripts/package-dmg.sh` or `bash lumaflow/scripts/package-dmg.sh`.

**Releases:** GitHub Actions builds MacMotion v1.8 and LumaFlow v0.8 DMGs independently, including their custom app icons.

**Privacy:** LumaFlow requests Screen Recording access only when the user enables screen luminance analysis; it does not store or upload captures.

Both apps feature an opt-in **Check for Updates…** menu item that verifies GitHub Release DMGs before offering verified Install & Relaunch (with a manual-install fallback). Both default to Launch at Login after installation.

These builds are ad-hoc signed for integrity but **not notarized**. Downloaded applications may need a deliberate one-time Gatekeeper override; instructions are in each app's README. Distribution without overrides requires Developer ID signing and notarization.

Both apps are independent projects, not copies of the upstream inspiration. MIT licensed.
