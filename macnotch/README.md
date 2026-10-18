# MacNotch v0.6

MacNotch is a native macOS productivity panel that unfolds from the camera notch. The compact black pill stays close to the built-in notch size. Hover or click to open the glass panel, pin it, or use **Control–Option–N**. Settings includes **Hide MacNotch in full-screen apps**, enabled by default.

## Working features

- **File Tray:** drag files and folders onto the notch or add them through the file picker. Entries remain available across launches. Drag an entry back out, open it, reveal it in Finder, or remove it from the tray. Create a ZIP archive on the Desktop from the tray contents. The tray stores file paths and does not move or copy the originals.
- **System Widgets:** locally sampled CPU use, memory use, top resident-memory process, primary `en*` network-interface upload/download rates, and free disk space. CPU/memory/network values refresh about every two seconds; the top process refreshes every ten seconds. Network sampling uses the primary wired/wireless adapter and cannot guarantee that a particular adapter is Wi-Fi.
- **Live Activities:** reports MacNotch's current music playback, Focus timer, file-tray contents, and frontmost application. It currently does not read third-party meeting, download, call, recording, or system-wide activity feeds.
- **Music:** connect Apple Music or Spotify and approve macOS Automation access. The player shows track and artist, previous/play/pause/next controls, and a seekable progress bar. The compact notch stays small.
- **Gemini:** send typed prompts through Google's Gemini API using your own API key, stored in this app's Keychain entry. Input/output token usage is shown per request and for the session. This is separate from Gemini consumer account limits and billing; account remaining usage is not available here. Sending is explicit.
- **Clipboard:** explicitly enable in-memory session history, up to 20 clips. Copy items or combine selected text. Clear or disable to erase it; concealed, transient and generated content and common password-manager foreground apps are excluded.
- **Focus and MacPulse glance:** use a local focus timer and read a timestamped RAM/CPU snapshot written by MacPulse.
- **Notes, Siri, and Shortcuts:** notes save locally; Siri opens Apple's own interface rather than running inside MacNotch.
- **Hardware feedback:** optional volume and brightness-key indications. macOS exposes brightness direction rather than a dependable percentage on supported Macs.

## Features still being built

The broader Droppy feature set is not complete in MacNotch yet. In particular, MacNotch does not currently provide third-party live-activity integrations, recording controls, meeting controls, a lock-screen player, calendar widgets, floating-player layouts, or the full extension catalog. Those will be developed and tested in later increments. MacNotch is an original implementation and does not include Droppy's code, artwork, or name.

The active ChatGPT or Gemini app can be recognized by its frontmost application only. ChatGPT's desktop app does not expose account token or remaining-quota data, so MacNotch does not invent those counters.

## Build and checks

Run `bash scripts/package-utility.sh MacNotch` on macOS 14+ with Xcode and XcodeGen. It creates a universal Apple Silicon/Intel DMG and checksum. The beta is ad-hoc signed and unnotarized. macOS permission prompts, file drag-and-drop, display arrangements, full-screen Spaces, and player Automation need testing on the target Mac. Gemini requests require a user-provided API key and network access.

Run `bash scripts/check-utilities.sh` to check shared utility behavior, Gemini response handling, and local MacNotch system sampling.

## v0.6

Added a persistent file tray with drag-in/drag-out, open, Finder reveal, removal and ZIP creation. Added local system widgets for CPU, RAM, top RAM process, network rates and disk space, plus a live view of states MacNotch currently tracks. The catalog continues to expand in later releases.
