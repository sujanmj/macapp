# MacMotion v1.4

**MacMotion** is a free native macOS menu-bar live wallpaper app with a **separate, installable screen saver**.

- Loop your own MP4/MOV video behind the desktop icons.
- Select a video in the MacMotion menu-bar app. That same video is used by the screen saver.
- Installs `MacMotion.saver` into `~/Library/Screen Savers/` to appear in **System Settings → Wallpaper → Screen Saver… → Custom**.
- Supports Apple Silicon (arm64) and macOS 14+; built and packaged with Xcode and XcodeGen.
- Distinct colorful MacMotion app icon, a Finder icon for the .saver bundle, and a System Settings screen-saver preview tile.
- Offline, no advertisements or tracking.

## Check for updates

Use the **Check for Updates…** menu-bar item. The app reads published GitHub Releases with tags `macmotion-vX.Y`, compares semantic versions, and offers to download the matching `MacMotion-vX.Y.dmg`. It **verifies the release's SHA-256 digest** before opening the DMG. Installation is manual: drag the new `MacMotion.app` to Applications and relaunch. It never silently replaces a running app. Internet access is used only when you choose to check.

## Build & package

```sh
brew install xcodegen librsvg
git clone https://github.com/sujanmj/macapp.git
cd macapp/macmotion
bash scripts/package-dmg.sh
```

This creates `MacMotion-v1.4.dmg` containing `MacMotion.app`, `MacMotion.saver`, and an Applications shortcut.

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
