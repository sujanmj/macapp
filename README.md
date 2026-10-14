# macapp — free native macOS utilities

Seven independent macOS apps, each with its own XcodeGen project and source tree:

| App | Description | Build |
| --- | --- | --- |
| [MacPulse](macpulse/) | Free system monitor, safe log cleaner, read-only duplicate finder, existing VPN controls, native memory widget | `cd macpulse && bash scripts/package-dmg.sh` |
| [MacMotion](macmotion/) | MP4/MOV live desktop wallpaper menu-bar app | `cd macmotion && xcodegen generate && open MacMotion.xcodeproj` |
| [LumaFlow](lumaflow/) | Experimental content-aware built-in display auto brightness, inspired by Rubarb | `cd lumaflow && xcodegen generate && open LumaFlow.xcodeproj` |
| [MacShelf](macshelf/) | Collect files across folders and copy/drag the whole batch | `bash scripts/package-utility.sh MacShelf` |
| [MacSwitch](macswitch/) | Option–Tab between individual accessible windows | `bash scripts/package-utility.sh MacSwitch` |
| [MacNotch](macnotch/) | Compact media, clipboard, GPT, Siri launch, focus and file handoff | `bash scripts/package-utility.sh MacNotch` |
| [MacVoice](macvoice/) | Local/cloud dictation with safe paste and optional AI editing | `bash scripts/package-utility.sh MacVoice` |

Requires macOS 14+, Xcode, and `brew install xcodegen librsvg`.

**Packaging:** `bash macmotion/scripts/package-dmg.sh`, `bash lumaflow/scripts/package-dmg.sh`, or `bash macpulse/scripts/package-dmg.sh`.

**Releases:** GitHub Actions builds MacMotion v1.8 LumaFlow v0.8, and MacPulse v1.1 DMGs independently, including their custom app icons.

**Privacy:** LumaFlow requests Screen Recording access only when the user enables screen luminance analysis; it does not store or upload captures.

The original three apps feature an opt-in **Check for Updates…** menu item that verifies GitHub Release DMGs before offering verified Install & Relaunch (with a manual-install fallback). MacMotion and LumaFlow default to Launch at Login after installation; MacPulse does not add itself automatically.

These builds are ad-hoc signed for integrity but **not notarized**. Downloaded applications may need a deliberate one-time Gatekeeper override; instructions are in each app's README. Distribution without overrides requires Developer ID signing and notarization.

All seven are independent projects, not copies of the upstream inspiration. MIT licensed.

**MacPulse 1.1:** local health recommendations, system metrics, customizable WidgetKit panels, explicit storage and developer-file review, security checks, network/VPN control for existing providers, guarded application management and SHA256-verified manual update checks. No malware engine, no standalone VPN server and no unreviewed cleanup.


**New utility builds (v0.1):** the Desktop Utilities workflow builds universal Apple Silicon/Intel DMGs and checksum manifests for MacShelf, MacSwitch, MacNotch and MacVoice. After all four builds and checks pass, it publishes separate beta releases with verified DMGs and checksums. Each app folder has a downloads page linking to its own installer. Their README files document supported interactions, setup and first-device checks. API-backed GPT/transcription/editing requires a user-provided OpenAI key and separate API billing. The apps are early implementations with explicit parity gaps; none claims proprietary-product accuracy or full feature parity.
