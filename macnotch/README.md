# MacNotch v0.16

MacNotch is a native macOS productivity panel that unfolds from the camera notch. The compact black pill stays close to the built-in notch size. Hover or click to open the glass panel, pin it, or use **Control–Option–N**. Settings includes **Hide MacNotch in full-screen apps**, enabled by default.

## Working features

- **File Tray:** drag files and folders onto the notch or add them through the file picker. Open the separate floating shelf to keep items visible across apps. Entries remain available across launches. Select multiple entries and copy their file references to paste into Finder or another app; share, open, reveal, or remove individual items; create a ZIP archive from all or selected files and choose where to save it. The tray stores file paths and does not move or copy the originals.
- **Floating Shelf Shortcut:** use **Control–Option–F** from anywhere to open the file shelf. Its size and screen position are restored between launches.
- **System Widgets:** locally sampled CPU use, memory use, top resident-memory process, primary `en*` network-interface upload/download rates, and free disk space. CPU/memory/network values refresh about every two seconds; the top process refreshes every ten seconds. Network sampling uses the primary wired/wireless adapter and cannot guarantee that a particular adapter is Wi-Fi.
- **Live Activities:** reports MacNotch's current music playback, Focus timer, file-tray contents, and frontmost application. It currently does not read third-party meeting, download, call, recording, or system-wide activity feeds.
- **Screen Recording:** record the primary display to `Movies/MacNotch Recordings`, with optional system audio and (on macOS 15+) microphone capture. MacNotch is excluded from the captured video and shows a small in-progress indicator at the notch. Capture starts only after you press the button and grant macOS permission.
- **Meeting Notes:** after recording, explicitly transcribe the latest movie or choose an earlier recording. MacNotch extracts audio locally, requires Apple's on-device speech recognition, and saves a `.txt` transcript beside the movie. It does not upload recordings; unsupported languages stop with an explanation.
- **Screen Capture & Text:** capture the entire primary display or one visible app window on demand, drag a crop in the preview, draw cyan markup on a separate image copy, and recognize visible text locally with Apple Vision. Captures save as PNGs in `Pictures/MacNotch Captures`.
- **Music:** connect Apple Music or Spotify and approve macOS Automation access. The player shows track and artist, previous/play/pause/next controls, and a seekable progress bar. The compact notch stays small.
- **Gemini:** send typed prompts through Google's Gemini API using your own API key, stored in this app's Keychain entry. Input/output token usage is shown per request and for the session. This is separate from Gemini consumer account limits and billing; account remaining usage is not available here. Sending is explicit.
- **Clipboard:** explicitly enable in-memory session history, up to 20 clips. Copy items or combine selected text. Clear or disable to erase it; concealed, transient and generated content and common password-manager foreground apps are excluded.
- **Focus and MacPulse glance:** use a local focus timer and read a timestamped RAM/CPU snapshot written by MacPulse.
- **Notes, Siri, and Shortcuts:** notes save locally; Siri opens Apple's own interface rather than running inside MacNotch.
- **Hardware feedback:** optional volume and brightness-key indications. macOS exposes brightness direction rather than a dependable percentage on supported Macs.

## Features still being built

The broader Droppy feature set is not complete in MacNotch yet. In particular, MacNotch does not currently provide third-party live-activity integrations, meeting controls, a lock-screen player, calendar widgets, floating-player layouts, or the full extension catalog. Those will be developed and tested in later increments. MacNotch is an original implementation and does not include Droppy's code, artwork, or name.

See [ROADMAP.md](ROADMAP.md) for the current feature-by-feature implementation tracker.

The active ChatGPT or Gemini app can be recognized by its frontmost application only. ChatGPT's desktop app does not expose account token or remaining-quota data, so MacNotch does not invent those counters.

## Build and checks

Run `bash scripts/package-utility.sh MacNotch` on macOS 14+ with Xcode and XcodeGen. It creates a universal Apple Silicon/Intel DMG and checksum. The beta is ad-hoc signed and unnotarized. macOS screen, microphone, player Automation permissions, file drag-and-drop, display arrangements, full-screen Spaces, and real recording output need testing on the target Mac. Gemini requests require a user-provided API key and network access.

Run `bash scripts/check-utilities.sh` to check shared utility behavior, Gemini response handling, MacNotch system sampling, and local Vision OCR on a generated test image. The meeting transcription flow compiles into the universal app; real transcription depends on macOS language assets and user-granted Speech Recognition permission.

## v0.12

Added user-requested meeting transcription for saved screen recordings. Audio extraction and speech recognition are constrained to the Mac; transcription is an explicit action and saves a neighboring text file. Added the speech-recognition usage prompt and signing entitlement, and made packaging verify that entitlement.

## v0.13

Added multi-select file references for the tray, so several items can be copied together and pasted into Finder or compatible apps. Added system Share actions and per-item Copy Path context actions. These only share or copy references; original files stay in place.

## v0.14

Added a separate floating file shelf, available from the File Tray and menu bar. It accepts dropped files and folders, allows drag-out, and shares the tray's multi-select copy action, so the shelf can stay available while you work in other apps.

## v0.15

Added the global Control–Option–F shortcut for the floating shelf and restored the shelf's saved frame across launches.

## v0.16

ZIP creation now archives only the selected tray files when a selection exists, and asks where to save the archive. With no selection, it archives the full tray. The floating shelf exposes the same action; source files remain untouched.

## v0.11

Added freehand cyan markup over screenshot or crop previews, with a separate saved copy so the original capture stays intact. Added a generated-image renderer check that verifies image dimensions, visible markup pixels, and OCR text retention.

## v0.10

Added a drag-to-select crop in the capture preview, with a saved crop image and local OCR of the selected area. Annotation and drawing tools remain planned.

## v0.9

Added window-targeted screen captures with an on-demand list of visible app windows. OCR remains local, asynchronous, and copyable; region selection and annotation remain planned.

## v0.8

Added an on-demand screenshot workflow with local Vision OCR, a preview, and copyable recognized text. Screenshots save locally; region selection and markup remain planned.

## v0.7

Added an on-demand display recorder with optional system audio and microphone capture, plus a compact recording timer and stop control at the notch. MacNotch's own panel is excluded from the movie. Microphone capture requires macOS 15 or later and user permission.

## v0.6

Added a persistent file tray with drag-in/drag-out, open, Finder reveal, removal and ZIP creation. Added local system widgets for CPU, RAM, top RAM process, network rates and disk space, plus a live view of states MacNotch currently tracks. The catalog continues to expand in later releases.
