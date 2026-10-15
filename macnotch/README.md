# MacNotch v0.4

MacNotch is a native macOS productivity panel. While collapsed, it stays a small black pill close to the built-in camera notch size, with a subtle MacNotch mark. Hover or click to unfold its colorful glass dashboard; pin it open or use **Control–Option–N** to toggle it. Settings includes **Hide MacNotch in full-screen apps**, enabled by default.

- **Music:** connect Apple Music or Spotify and approve macOS Automation access. The expanded player shows track and artist, previous/play/pause/next controls, and a seekable progress bar. The compact notch stays small.
- **Gemini:** send typed prompts through the official Google Gemini API with your own API key stored in this app's Keychain entry. API input/output token usage is shown per request and for the session. This is separate from Gemini consumer account limits and billing; account remaining usage is not available here. Sending is explicit.
- **Clipboard:** explicitly enable in-memory session history, up to 20 clips. Copy items or combine selected text. Clear or disable to erase it; concealed, transient and generated content and common password-manager foreground apps are excluded.
- **Focus and MacPulse glance:** use a local focus timer and read a timestamped RAM/CPU snapshot written by MacPulse.
- **Notes, Siri, and Shortcuts:** notes save locally; Siri opens Apple's own interface rather than running inside MacNotch.
- **Hardware feedback:** optional volume and brightness-key indications. macOS exposes brightness direction rather than a dependable percentage on supported Macs.

The active ChatGPT or Gemini app can be recognized by its frontmost application only. ChatGPT's desktop app does not expose account token or remaining-quota data, so MacNotch does not invent those counters. Gemini API usage appears in the Gemini panel.

## Build and checks

Run `bash scripts/package-utility.sh MacNotch` on macOS 14+ with Xcode and XcodeGen. It creates a universal Apple Silicon/Intel DMG and checksum. Beta builds are ad-hoc signed and unnotarized. macOS permission prompts, display arrangements, full-screen Spaces, and player Automation should be tested on the target Mac. Gemini requests require a user-provided API key and network access.
