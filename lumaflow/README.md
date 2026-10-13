# LumaFlow — content-aware brightness for macOS

An independent, **experimental** free and open-source alternative inspired by [Rubarb](https://rubarb.bar/). It is not affiliated with Rubarb.

LumaFlow uses ScreenCaptureKit to sample an approximately 160×100 representation of the display twice per second. It calculates screen luminance locally and gently adjusts the MacBook's built-in display brightness. It keeps no screenshots, browsing history, or content logs, and has no network code.

## Build (macOS 14+, Apple Silicon)

Install Xcode and XcodeGen (`brew install xcodegen`), then from this directory:

```sh
xcodegen generate
open LumaFlow.xcodeproj
```

Press Cmd+R. Click **◐** in the menu bar and choose **Enable Auto Brightness**. macOS requires Screen Recording permission: System Settings → Privacy & Security → Screen & System Audio Recording. Restart the app after granting permission if needed.

To make a DMG: `bash scripts/package-dmg.sh`.

## Important limitations

- **Prototype, not an exact Rubarb clone.** No machine-learning model, individual website presets, or external-monitor DDC.
- Brightness adjustment uses the private macOS DisplayServices framework dynamically, which may stop working in future macOS versions. Mac App Store submission is not supported.
- Screen Recording permission is needed to sample luminance; sampling is off by default.
- Uses the main screen capture and the built-in-display brightness control; external screens are not supported.
- Avoid using this if you require stable display brightness for color-critical work.
- Build has not yet been verified on a physical Mac; test on your MacBook Air before distributing.

MIT licensed. See repository LICENSE.
