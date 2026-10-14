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
