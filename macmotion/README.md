# MacMotion v1.7

**MacMotion** is a free native macOS menu-bar live wallpaper app with a **separate, installable screen saver**.

- Loop your own MP4/MOV video behind the desktop icons.
- Select a video in the MacMotion menu-bar app. That same video is used by the screen saver.
- Installs `MacMotion.saver` into `~/Library/Screen Savers/` to appear in **System Settings → Wallpaper → Screen Saver… → Custom**.
- Supports Apple Silicon (arm64) and macOS 14+; built and packaged with Xcode and XcodeGen.
- Distinct colorful MacMotion app icon, a Finder icon for the .saver bundle, and a System Settings screen-saver preview tile.
- Offline, no advertisements or tracking.

## Check for updates

Use the **Check for Updates…** menu-bar item. The app reads published GitHub Releases with tags `macmotion-vX.Y`, compares semantic versions, and offers to download the matching `MacMotion-vX.Y.dmg`. It verifies the release SHA-256 digest before offering **Install & Relaunch**. An embedded helper replaces the app after it quits, without bypassing Gatekeeper; if installation fails, the verified DMG opens for manual installation. Internet access is used only on request.

## Build & package

```sh
brew install xcodegen librsvg
git clone https://github.com/sujanmj/macapp.git
cd macapp/macmotion
bash scripts/package-dmg.sh
```

This creates `MacMotion-v1.7.dmg` containing `MacMotion.app`, `MacMotion.saver`, and an Applications shortcut.

## Install and enable

1. Open the DMG and drag **MacMotion.app** to **Applications**.
2. Start **MacMotion**, click its `◉` icon in the menu bar, and select a local MP4/MOV video.
3. Click **Install Screen Saver…** in that menu. The MacMotion app includes the saver in its Resources folder. Alternatively, double-click **MacMotion.saver** in the DMG and install it for the current user, or run `bash scripts/install-screen-saver.sh`.
4. Open **System Settings → Wallpaper → Screen Saver… → Custom**. Select **MacMotion**. macOS uses its normal inactivity timer to activate it.

On newer macOS releases, the Screen Saver picker is reached from the Wallpaper settings, as shown in macOS Tahoe. If it doesn't appear immediately, quit and reopen System Settings.

## Important distinction

**MacMotion.saver is listed in the macOS Screen Saver picker, not in Apple's main Wallpaper gallery.** Adding a video collection to the main gallery requires private `WallpaperExtensionKit` interfaces (see the third-party [Phosphene project](https://github.com/kageroumado/phosphene)), which are not yet incorporated into MacMotion.

The saver uses a `ScreenSaverView` plug-in and AVFoundation video rendering; it reads the last selected video path from the MacMotion app's preferences domain. Moved or inaccessible videos cannot play. The screen-saver engine may block access to certain locations because of sandbox restrictions; if so, use a video in your Movies folder and reselect it in MacMotion.

## Known limits

- This release **does not** provide a native macOS lock-screen live wallpaper or Apple's own dynamic Wallpaper gallery tile.
- Third-party `.saver` modules can have preview or lifecycle differences between macOS releases, especially Tahoe.
- Built for Apple Silicon; no Intel slice yet.
- Ad-hoc-signed screen saver and unsigned app are intended for personal testing; an official Developer ID notarized distribution will require Apple signing credentials.
- Existing desktop wallpaper feature works separately from the screen saver.

## License

MIT. Independent implementation, inspired by [LiveWallpaperMacOS](https://github.com/thusvill/LiveWallpaperMacOS).

## macOS Gatekeeper and downloaded DMGs (important)

The automated public GitHub builds are **ad-hoc code signed and integrity checked**,
but are **not signed with an Apple Developer ID and are not notarized**. Consequently,
Safari-downloaded DMGs may show "cannot be verified" or even "is damaged and can't
be opened" on macOS. A valid DMG checksum does not establish Apple trust.

**First, drag MacMotion.app out of the mounted DMG into Applications.** Do not
launch it directly from inside the mounted DMG.

For a known trusted download, first compare the SHA-256 printed by:

```sh
shasum -a 256 ~/Downloads/MacMotion-v1.7.dmg
```

with the `sha256:` digest on the matching [GitHub release](https://github.com/sujanmj/macapp/releases).
Then try to open `/Applications/MacMotion.app`. Check **System Settings →
Privacy & Security → Open Anyway** if available.

If macOS still refuses with "damaged" *after you've verified the exact release
digest* and trust this repository's source, the following removes the
quarantine flag **only** from MacMotion (not system-wide):

```sh
xattr -dr com.apple.quarantine /Applications/MacMotion.app
open /Applications/MacMotion.app
```

This deliberately bypasses Gatekeeper's downloaded-file quarantine protection.
Use it only after reviewing the source and verifying the intended release.
If `codesign --verify --deep --strict /Applications/MacMotion.app` fails on
v1.7, do **not** override the error; report the build issue.

To create a normally trusted DMG, sign with your Apple-issued Developer ID
certificate and notarize:

```sh
MACAPP_SIGNING_IDENTITY="Developer ID Application: YOUR NAME (TEAMID)" \
MACAPP_NOTARY_PROFILE="YOUR_NOTARYTOOL_KEYCHAIN_PROFILE" \
bash scripts/package-dmg.sh
```

The above environment variables must correspond to real credentials already
configured in your macOS Keychain; the repository does not include credentials.

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


### Already registered but not enabled?

If the **Launch at Login** menu says **Enable Launch at Login in Settings…**, macOS has already registered the item, and a second registration is not needed. Click it to open Apple's **System Settings → General → Login Items & Extensions**, enable **MacMotion**, then reopen MacMotion and confirm the menu item is checked. **Open Login Items Settings…** is always available from the menu. The app does not delete existing records or override the system's permission.
