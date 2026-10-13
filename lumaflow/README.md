# LumaFlow — content-aware brightness for macOS

An independent, **experimental** free and open-source alternative inspired by [Rubarb](https://rubarb.bar/). It is not affiliated with Rubarb.

LumaFlow uses ScreenCaptureKit to sample an approximately 160×100 representation of the display twice per second. It calculates screen luminance locally and gently adjusts the MacBook's built-in display brightness. It keeps no screenshots, browsing history, or content logs, and makes no network requests except when you explicitly choose Check for Updates.

## Build (macOS 14+, Apple Silicon)

Install Xcode, XcodeGen, and librsvg (`brew install xcodegen librsvg`), then from this directory:

```sh
xcodegen generate
open LumaFlow.xcodeproj
```

Press Cmd+R. Click **◐** in the menu bar and choose **Enable Auto Brightness**. macOS requires Screen Recording permission: System Settings → Privacy & Security → Screen & System Audio Recording. Restart the app after granting permission if needed.

To make a DMG: `bash scripts/package-dmg.sh` (outputs `LumaFlow-v0.6.dmg`).

LumaFlow v0.6 adds a high-resolution app icon (half-lit sun) and a native system-symbol menu bar icon.

## Check for updates

Use the **Check for Updates…** menu-bar item. The app reads published GitHub Releases with tags `lumaflow-vX.Y`, checks the installed app version, downloads the matching DMG after confirmation, verifies its GitHub SHA-256 digest, and offers **Install & Relaunch**. A separate helper waits until the app quits, verifies the replacement bundle, and installs it to /Applications without bypassing Gatekeeper. A manual DMG fallback is provided. The update check is the only network action in the app.

## Important limitations

- **Prototype, not an exact Rubarb clone.** No machine-learning model, individual website presets, or external-monitor DDC.
- Brightness adjustment uses the private macOS DisplayServices framework dynamically, which may stop working in future macOS versions. Mac App Store submission is not supported.
- Screen Recording permission is needed to sample luminance; sampling is off by default.
- Uses the main screen capture and the built-in-display brightness control; external screens are not supported.
- Avoid using this if you require stable display brightness for color-critical work.
- Build has not yet been verified on a physical Mac; test on your MacBook Air before distributing.

MIT licensed. See repository LICENSE.

## macOS Gatekeeper and downloaded DMGs

The public GitHub installer is **ad-hoc signed** to verify bundle integrity
but has no Apple Developer ID signature or notarization. Some macOS releases
will say an internet-downloaded app "is damaged" even if the DMG checksum is valid.

Drag **LumaFlow.app** from the DMG into **Applications** before launching.
Verify `shasum -a 256 ~/Downloads/LumaFlow-v0.6.dmg` against the SHA-256 digest
shown on its [GitHub release](https://github.com/sujanmj/macapp/releases).
Try **System Settings → Privacy & Security → Open Anyway** if presented.

If it is still blocked, and only if you trust this specific release and
have checked its checksum, you can remove its quarantine attribute:

```sh
xattr -dr com.apple.quarantine /Applications/LumaFlow.app
open /Applications/LumaFlow.app
```

That bypasses a macOS protection for this app; never do it for unknown downloads.
The code signature can be verified locally using
`codesign --verify --deep --strict /Applications/LumaFlow.app`.
If signature verification fails, stop and report the problem.

Developer ID signing and notarization require Apple's developer credentials.
With those already configured in Keychain, build via:

```sh
MACAPP_SIGNING_IDENTITY="Developer ID Application: YOUR NAME (TEAMID)" \
MACAPP_NOTARY_PROFILE="YOUR_NOTARYTOOL_KEYCHAIN_PROFILE" \
bash scripts/package-dmg.sh
```

## Start at login and one-click updates

- **Launch at Login** is enabled by default on first launch **from /Applications**.
  Manage it with the checked menu-bar option, or under **System Settings → General → Login Items & Extensions**.
  macOS may require a one-time approval. Running from Xcode or a mounted DMG does not register a login item.
- **Check for Updates…** reads this repository's published GitHub Releases on demand.
  When a newer version is available, choose **Download Update** then **Install & Relaunch**.
  It verifies the GitHub SHA-256 digest and the downloaded app's bundle identifier,
  version and code signature before replacing the existing installation.
- A small signed command-line helper inside the same app bundle waits for the app to
  exit and then attempts the replacement in `/Applications` before relaunching.
  It keeps a rollback copy until validation succeeds, and **never requests root privileges or strips Gatekeeper quarantine**.
  If automatic replacement is denied, the verified DMG opens for manual installation.
- These releases are still **not Apple-notarized**; you may have to use Apple's
  **Open Anyway** mechanism again after an update. Installing from Finder is
  also supported.


### Existing login item needs approval?

If the menu shows **Enable Launch at Login in Settings…**, click it to open Apple's **Login Items & Extensions** pane. Enable **LumaFlow** there. This is an already-registered login item: the app will **not** attempt duplicate registration. You can also use **Open Login Items Settings…** in the menu at any time.
