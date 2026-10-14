# MacNotch v0.1

A native compact top-of-screen companion. A small black pill stays below the menu bar/camera notch, expands on hover and collapses after leaving. Click or pin to keep it expanded; **Control–Option–N** toggles expansion. Works on notchless/external displays too. Drag the panel to reposition; screen changes restore its main-screen placement.

- **Music:** connect Music or Spotify, approve Automation access, then see track/artist and control previous/play/pause/next. No private MediaRemote framework or arbitrary-player scraping. Polling is enabled only after Connect.
- **Clipboard:** explicitly enable history for the current session. Holds up to 20 text/image/rich-content/file-reference clips (2 MB per clip) in memory. Copy individual clips or combine selected text in collection order. Clear or disable to erase history. Marked concealed/transient/generated clipboard content and common password-manager foreground apps are excluded; not all applications mark sensitive content, so pause capture when needed.
- **GPT:** single-message text chat through the official OpenAI Responses API, with your own API key stored in this app's Keychain entry. Send is the only trigger. Model is configurable (default `gpt-4.1-mini`); responses use `store=false`. API billing/account access is separate from a ChatGPT subscription. Open ChatGPT is also available as a browser shortcut. Cancel/clear invalidate old responses, so they cannot overwrite new conversations. No live API calls were made during build verification.
- **Siri:** launches Apple's Siri interface, with Siri Settings fallback. Siri itself cannot be embedded in this panel through the supported macOS 14 APIs.
- **Focus + MacPulse glance:** 25-minute local focus timer with completion sound. Explicitly read MacPulse v1.1's timestamped local RAM/CPU/top-app snapshot and open its confirmed high-RAM-app review. This connects the utilities; it is not a claim that no other product has similar features.
- **Files:** launch MacShelf or drop Finder file URLs on the pill to hand files to MacShelf. MacShelf must be installed in Applications; promised-file exports belong in the shelf itself.

Settings configure optional OpenAI access, model and opt-in login. Clipboard and chat are not saved to disk. macOS and API providers still apply their own data/access policies.

## Build and checks

`bash scripts/package-utility.sh MacNotch`; Xcode/XcodeGen, macOS 14+. Universal Apple Silicon/Intel DMG/checksum; ad-hoc signed, unnotarized. CI publishes beta installers only after all four builds/checks pass; see [downloads](downloads/README.md).

Test hover/pin/collapse, external displays/full-screen Spaces, Music/Spotify Automation allow/deny, clipboard capture off/clear/combined ordering/marked concealment, Siri enabled/disabled, file handoff, focus timer, missing/stale MacPulse snapshot, and GPT with a user-provided key. API calls require connectivity and valid billing; compilation does not verify service accuracy/availability.

## v0.2

Top-edge black panel with camera-safe spacing, animated expansion/collapse, hover intent, quick collapse and Reduce Motion support. Existing Music/Spotify, Clipboard, GPT, Focus and MacShelf handoff remain available. This is an original interface inspired by the requested NotchNook reference; system-wide media, mirror and calendar integration are not included.

## v0.3

Compact Home dashboard with an Ask button, developer tools, music, date/focus cards and consistent pill navigation. File Shelf was removed from MacNotch. The collapsed panel shows the active application's icon/name (including Chrome, Safari or ChatGPT), never an app-brand label. This reads the frontmost app only, not browser tabs or page content.

- Ask uses your OpenAI API key. Last-request input/output tokens and session total come from API responses. ChatGPT account limits/remaining balance are unavailable; no guessed counters.
- Developer tools: local JSON formatting, SHA-256, UUID and Unix timestamp. Quick notes save locally; Siri and Shortcuts launchers live alongside notes.
- Volume feedback uses the output device's reported level, when available, including changes made outside hardware keys. Brightness hardware keys show up/down direction; actual brightness percentages are not exposed reliably across supported Macs. Apple’s own HUD is retained. Hardware-key detection depends on macOS/device permissions; Settings offers Input Monitoring and an off switch.
- Hover intent, animated top-edge opening/closing, camera spacing and Reduce Motion remain. Calendar event access, camera mirror and system-wide media playback are not implemented; Music/Spotify use explicit Automation consent.
