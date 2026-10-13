# MacMotion

**MacMotion** is a free, lightweight, native macOS menu-bar app that plays a local video as a live desktop wallpaper.

- macOS 14+; Apple Silicon supported
- MP4 and MOV video playback, muted and seamlessly looped using AVFoundation
- Desktop-level windows behind desktop icons, one per connected display
- Menu-bar picker and pause/resume controls
- Pause during sleep and (optionally) when macOS Low Power Mode is enabled
- Remembers the selected video location
- No accounts, subscription, analytics, or network requests

MacMotion is an **independent implementation** inspired by [thusvill/LiveWallpaperMacOS](https://github.com/thusvill/LiveWallpaperMacOS), not a fork or copy of its source.

## Build and run

Install [Xcode](https://apps.apple.com/app/xcode/id497799835) (launch it once) and XcodeGen:

```sh
brew install xcodegen
git clone https://github.com/sujanmj/macapp.git
cd macapp
xcodegen generate
open MacMotion.xcodeproj
```

In Xcode, select **MacMotion → My Mac** and press **Cmd+R**. Use the **◉** menu-bar icon to select an MP4 or MOV video.

## Build a DMG

Run this from the repository root on a Mac with Xcode and XcodeGen:

```sh
bash scripts/package-dmg.sh
```

This creates `MacMotion-v1.1.dmg` in the repository root containing `MacMotion.app` and an Applications shortcut. To install, open the DMG and **drag MacMotion.app to Applications**; mounting a DMG does not install its app.

The app is built **unsigned and not notarized**. macOS Gatekeeper may warn on other Macs. This is intended for personal testing, not a notarized public release.

### GitHub Actions

The build workflow can be run manually from the Actions tab. Pushing a tag such as `v1.1` will also build a DMG and publish it as a GitHub Release asset.

## Known limitations

- Same video on all displays; per-display choices and playlists are not yet implemented.
- No live lock-screen wallpaper or fullscreen-app auto-pause.
- Files are remembered by path; moved/deleted files must be selected again.
- Desktop/window layering may vary with macOS desktop and Spaces settings.

## License

MIT. See [LICENSE](LICENSE).
