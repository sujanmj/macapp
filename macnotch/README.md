# MacNotch v0.29

MacNotch is a native macOS productivity panel that unfolds from the camera notch. The compact black pill stays close to the built-in notch size. Hover or click to open the glass panel, pin it, or use **Control–Option–N**. Settings includes **Hide MacNotch in full-screen apps**, enabled by default.

## Working features

- **File Tray:** drag files and folders onto the notch or add them through the file picker. In Finder, use Services → Add to MacNotch File Tray to add selected items directly. Open the separate floating shelf to keep items visible across apps. Entries remain available across launches. Select multiple entries and copy their file references, share them together, or copy them into a chosen or recent folder; name collisions get numbered copies, and originals are never moved or overwritten. Merge selected or all tray PDFs into a new PDF, preserving source order and pages. You can also open, reveal, or remove individual items; create a ZIP archive; and create smaller JPEG copies of images.
- **Floating File Shelf:** use **Control–Option–F** from anywhere, or quickly reverse direction twice while carrying files to reveal the shelf near your pointer. Drop the in-progress group there, then move the whole group together. Its size and screen position are restored between launches. Shake reveal is on by default and can be disabled in Settings; it observes pointer movement only.
- **System Widgets:** locally sampled CPU use, memory use, top resident-memory process, primary `en*` network-interface upload/download rates, and free disk space. CPU/memory/network values refresh about every two seconds; the top process refreshes every ten seconds. Network sampling uses the primary wired/wireless adapter and cannot guarantee that a particular adapter is Wi-Fi.
- **Live Activities:** reports MacNotch's current music playback, Focus timer, file-tray contents, and frontmost application. It currently does not read third-party meeting, download, call, recording, or system-wide activity feeds.
- **Screen Recording:** record the primary display or one selected visible app window to `Movies/MacNotch Recordings`, with optional system audio and (on macOS 15+) microphone capture. MacNotch is excluded from display captures and shows a small in-progress indicator at the notch. Capture starts only after you press the button and grant macOS permission; if a selected window is no longer available, recording stops with an explanation rather than falling back to the whole display.
- **Meeting Notes:** after recording, explicitly transcribe the latest movie or choose an earlier recording. MacNotch extracts audio locally, requires Apple's on-device speech recognition, and saves a `.txt` transcript beside the movie. It does not upload recordings; unsupported languages stop with an explanation.
- **Screen Capture & Text:** capture the entire primary display or one visible app window on demand, drag a crop in the preview, draw cyan markup on a separate image copy, and recognize visible text locally with Apple Vision. Captures save as PNGs in `Pictures/MacNotch Captures`.
- **Music:** connect Apple Music or Spotify and approve macOS Automation access. The player shows track and artist, previous/play/pause/next controls, and a seekable progress bar. Open the floating mini-player with **Control–Option–M** to keep controls available across apps; its size and location are restored between launches.
- **Gemini:** send typed prompts through Google's Gemini API using your own API key, stored in this app's Keychain entry. Input/output token usage is shown per request and for the session. This is separate from Gemini consumer account limits and billing; account remaining usage is not available here. Sending is explicit.
- **Clipboard:** explicitly enable session-only capture, up to 20 unpinned clips (2 MB each); search, copy, or combine selected text. Pinning explicitly saves that item in an unencrypted local app-support file on this Mac, up to 100 items / 8 MB total. Clear History removes session clips but keeps pins; Clear Pins deletes saved pins. Disabling capture removes session clips but keeps pins. Concealed, transient and generated content and common password-manager foreground apps are excluded.
- **Focus and MacPulse glance:** use a local focus timer and read a timestamped RAM/CPU snapshot written by MacPulse.
- **Calendar & Tasks:** explicitly load upcoming events from the next seven days or incomplete reminders due in the next month. MacNotch asks for Calendar or Reminders permission only after you press the matching load or create button. Create a reminder in your default Reminders list with an optional due date; marking one complete is a separate explicit action. Data stays local.
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

## v0.17

Added a Calendar tab that can display up to 40 upcoming events for the next seven days after the user explicitly loads them. Calendar permission is requested on demand and events are read locally; reminder and task editing are not included yet.

## v0.18

Added an on-demand Reminders view alongside events, listing incomplete reminders due in the next 30 days. Added a per-item Complete action, requested only after explicit loading, and a separate Reminders privacy usage description.

## v0.19

Added a Finder Services action that sends selected file references directly to MacNotch's tray and opens the tray for review. The installer build verifies the service's Info.plist registration and provider port.

## v0.20

Added an image quick action that downsamples oversized images to a 2048-pixel maximum edge and writes a JPEG copy with a compression setting tuned for smaller files. A Save panel chooses the destination; originals are never overwritten. Generated-image checks verify the output dimensions, file type, and source retention.

## v0.21

Added clipboard search and explicit per-item pinning. Unpinned history remains opt-in and session-only. Pinned clips are saved locally without encryption, with 100-item and 8 MB limits and dedicated clear controls; no cross-device sync is included. Checks cover successful rich-content round-trip, corrupt-file handling, and size/count rejection without overwriting existing data.

## v0.22

Added recording of a selected visible application window as an alternative to the primary display. MacNotch refreshes eligible windows on demand and before recording, excludes itself, and fails safely if the chosen window closes before capture begins. System audio and optional microphone behavior remain explicit.

## v0.23

Added explicit reminder creation to the Reminders view, with an optional due date and save to the default writable Reminders list. Permission is requested only when saving, and the list refreshes after a successful create. Also removed a duplicate ZIP action from the tray and corrected the Live Activities disclosure.

## v0.24

Added an optional, enabled-by-default shake gesture that reveals the floating file shelf beside the pointer during an active drag. The drag continues into the panel, so the carried files can be dropped into the shelf without opening it first. A deterministic test covers deliberate reversals, ordinary movement, and cooldown behavior.

## v0.25

Added multi-file sharing from both the notch tray and floating shelf. The action shares the selected files, or the full tray when nothing is selected, through the macOS share sheet. Files that have been removed from disk are omitted, and originals are never moved or rewritten.

## v0.26

Added **Send to Folder** from the notch tray and floating shelf. It copies selected items, or all items when nothing is selected, to a chosen folder. Existing files are kept; collisions receive numbered names. Copies run off the UI thread, and source items are never moved or modified. A deterministic test covers collisions, unchanged sources, and prevention of recursive folder copies.

## v0.27

Added **Merge PDFs** from the notch tray and floating shelf. It joins the selected PDFs, or all tray PDFs when nothing is selected, in tray order and saves a separate output file. Input PDFs cannot be used as the output path. A generated-document check verifies the merged page count, preserves both input files byte-for-byte, and confirms the overwrite guard.

## v0.28

Added a compact **Send** menu with the folder picker and up to six recent destinations. Chosen paths are stored locally, reused without reopening the picker, deduplicated, and capped to the most recent six. Missing folders are omitted, and users can clear the recent list at any time.

## v0.29

Added a separate floating **Now Playing** panel for Apple Music and Spotify with track and artist, previous/play-pause/next, seekable progress, player selection, and connection feedback. Open it from the Music tab, the menu bar, or **Control–Option–M**. Panel placement and size persist. Music access still uses macOS Automation permission.

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
