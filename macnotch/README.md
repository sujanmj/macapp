# MacNotch v0.60

MacNotch is a native macOS productivity panel that unfolds from the camera notch. The compact black pill stays close to the built-in notch size. Hover or click to open the glass panel, pin it, or use **Control–Option–N**. Settings includes **Hide MacNotch in full-screen apps**, enabled by default.

## Working features

- **File Tray:** drag files and folders onto the notch or add them through the file picker. Search by file or parent-folder name and select all visible matches. Image, video, audio, PDF, and other supported files show Quick Look thumbnails directly in the tray; use a row's context menu to open a larger in-app Quick Look preview. In Finder, use Services → Add to MacNotch File Tray to add selected items directly. Open the separate floating shelf to keep items visible across apps. Entries remain available across launches. Select multiple entries and copy their file references, share them together, or copy them into a chosen or recent folder; name collisions get numbered copies, and originals are never moved or overwritten. Merge selected or all tray PDFs into a new PDF, preserving source order and pages. You can also open, reveal, or remove individual items; create a ZIP archive; make smaller JPEG copies; convert selected images to full-resolution PNG copies; export selected MOV, MP4, and M4V videos as medium-quality MP4 copies; or convert WAV, AIFF, AIF, and CAF audio into M4A copies. A converted result is kept only when smaller than its source; output names are collision-safe, GPS metadata is stripped from PNG copies, and all source files stay unchanged.
- **External display islands:** each connected display without the built-in camera notch gets a compact MacNotch island with current playback or recording status. Expand it for live CPU, memory, upload, and download readings plus direct links to the shelf, player, widgets, and built-in notch; it hides in full-screen apps when that setting is enabled.
- **Emoji picker:** open macOS Emoji & Symbols from the Home panel or press **Control–Option–E**. Emoji insertion and search use Apple's native character palette.
- **App Launcher:** search local applications by display name or bundle identifier, open them directly, and save or remove favorites. Move through filtered results with the arrow keys and press Return to open the selected app. The catalog scans only standard local Applications folders; it does not index documents, inspect app contents, or send search data over the network.
- **Audio Control:** view and switch the current macOS sound output and adjust software volume or mute when the selected device exposes those controls. Output selection and volume changes are explicit; hardware-only device levels remain available through the device's own controls.
- **Window Snap:** move the focused window to the left or right half, maximize within the screen's usable area, or center it. The action is explicit and uses macOS Accessibility permission; MacNotch asks macOS to show its permission prompt when needed.
- **Stay Awake:** temporarily prevent idle display and system sleep for one, two, or four hours from Home. The assertion expires automatically, can be ended early, and does not override sleep caused by closing the lid or a system emergency.
- **Floating File Shelf:** use **Control–Option–F** from anywhere, or quickly reverse direction twice while carrying files to reveal the shelf near your pointer. Drop the in-progress group there, then move the whole group together. Its size and screen position are restored between launches. Shake reveal is on by default and can be disabled in Settings; it observes pointer movement only.
- **System Widgets:** locally sampled CPU use, memory use, top resident-memory process, primary `en*` network-interface upload/download rates, free disk space, and MacBook battery level/charging/time estimate. The floating monitor adds a CPU/RAM trend graph for its most recent 60 seconds, and Settings lets you choose which cards it displays. Open it from Widgets, the menu bar, or **Control–Option–W**; it stays above normal windows and remembers its size and position. CPU/memory/network values refresh about every two seconds; the top process refreshes every ten seconds. Network sampling uses the primary wired/wireless adapter and cannot guarantee that a particular adapter is Wi-Fi.
- **Live Activities:** reports MacNotch's current music playback, Focus timer, file-tray contents, and frontmost application. After you explicitly load Calendar or Reminders in Calendar & Tasks, it also shows your next event and earliest incomplete reminder here. Access remains on demand and local. It does not read third-party meeting, download, call, or system-wide activity feeds.
- **Screen Recording:** record the primary display or one selected visible app window to `Movies/MacNotch Recordings`, with optional system audio and (on macOS 15+) microphone capture. MacNotch is excluded from display captures and shows a small in-progress indicator at the notch. Capture starts only after you press the button and grant macOS permission; if a selected window is no longer available, recording stops with an explanation rather than falling back to the whole display. For meetings, **Stop & Transcribe** ends capture and starts the on-device transcript in one step; **Stop Recording** remains available on its own.
- **Meeting Notes:** record screen and audio together or capture audio-only to a local M4A file. Browse the 50 newest recordings, open a recording in its default player, create an on-device transcript for any listed item, and open the neighboring `.txt` transcript or timed `.srt` captions. Move a recording and any notes/captions beside it to Trash from the history after confirmation. MacNotch processes audio locally, requires Apple's on-device speech recognition for transcripts, and saves both files beside the recording. It does not upload recordings; unsupported languages stop with an explanation.
- **Screen Capture & Text:** capture the entire primary display or one visible app window on demand, drag a crop in the preview, draw cyan markup on a separate image copy, and recognize visible text locally with Apple Vision. Captures save as PNGs in `Pictures/MacNotch Captures`.
- **Music:** connect Apple Music or Spotify and approve macOS Automation access. The player shows album art, track and artist, previous/play/pause/next controls, and a seekable progress bar. Open the floating mini-player with **Control–Option–M** to keep controls available across apps; its size and location are restored between launches. Apple Music lyrics appear when the track provides them; its Playlist button previews and plays the first 15 tracks in the current playlist. Spotify playlist browsing and lyrics, and full queue management, remain future work.
- **Gemini:** send typed prompts through Google's Gemini API using your own API key, stored in this app's Keychain entry. Input/output token usage is shown per request and for the session. This is separate from Gemini consumer account limits and billing; account remaining usage is not available here. Sending is explicit.
- **Clipboard:** explicitly enable session-only capture, up to 20 unpinned clips (2 MB each); search, copy, or combine selected text. Pinning explicitly saves that item in an unencrypted local app-support file on this Mac, up to 100 items / 8 MB total. Clear History removes session clips but keeps pins; Clear Pins deletes saved pins. Disabling capture removes session clips but keeps pins. Concealed, transient and generated content and common password-manager foreground apps are excluded.
- **Focus and MacPulse glance:** use a local focus timer and read a timestamped RAM/CPU snapshot written by MacPulse.
- **Teleprompter:** save a local script, open a floating always-on-top reader, adjust scroll speed and text size, pause/resume/reset, and mirror the text for a beam-splitter setup. Control–Option–P opens the reader. Scrolling is local and requires no account or network access.
- **Calendar & Tasks:** explicitly load upcoming events from the next seven days or incomplete reminders due in the next month. Create an event in your default Calendar with a chosen start and duration, or create a reminder in your default Reminders list with an optional due date. MacNotch asks for Calendar or Reminders permission only when you load or save, and marking a reminder complete is a separate explicit action. Data stays local.
- **Notes, Siri, and Shortcuts:** notes save locally; Siri opens Apple's own interface rather than running inside MacNotch.
- **Hardware feedback:** optional volume and brightness-key indications. macOS exposes brightness direction rather than a dependable percentage on supported Macs.

## Features still being built

The broader Droppy feature set is not complete in MacNotch yet. Third-party live-activity integrations, meeting controls, a lock-screen player, calendar widgets, the full extension catalog, full player queue controls, Spotify/synchronized lyrics, and voice-follow teleprompter scrolling remain incomplete. MacNotch is an original implementation and does not include Droppy's code, artwork, or name.

See [ROADMAP.md](ROADMAP.md) for the current feature-by-feature implementation tracker.

The active ChatGPT or Gemini app can be recognized by its frontmost application only. ChatGPT's desktop app does not expose account token or remaining-quota data, so MacNotch does not invent those counters.

## Build and checks

Run `bash scripts/package-utility.sh MacNotch` on macOS 14+ with Xcode and XcodeGen. It creates a universal Apple Silicon/Intel DMG and checksum. The beta is ad-hoc signed and unnotarized. macOS screen, microphone, player Automation permissions, file drag-and-drop, display arrangements, full-screen Spaces, and real recording output need testing on the target Mac. Gemini requests require a user-provided API key and network access.

Run `bash scripts/check-utilities.sh` to check shared utility behavior, Gemini response handling, MacNotch system sampling, artwork URL and image validation, and local Vision OCR on a generated test image. The meeting transcription flow compiles into the universal app; real transcription depends on macOS language assets and user-granted Speech Recognition permission.

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

## v0.30

Added a compact floating **System Monitor** showing CPU, RAM, network upload/download, free disk space, and the top RAM-consuming process. Open it from the Widgets tab, menu bar, or **Control–Option–W**; it stays above normal windows and restores its size and position.

## v0.31

Added album artwork to the floating player for Apple Music and Spotify, plus a lyrics panel for lyrics supplied by the current Apple Music track. Spotify cover images are loaded from Spotify's published artwork URLs with HTTPS host validation and an 8 MB response cap. Spotify lyrics and music queue browsing remain future work.

## v0.32

Added a local battery card to the notch Widgets view and floating System Monitor on battery-equipped Macs. It reports normalized charge percentage, charging state, and macOS's estimated time remaining when available; desktop Macs and unavailable time estimates are handled without fabricated values.

## v0.33

Added a bounded rolling CPU/RAM history to the floating System Monitor. The compact graph uses the last 30 two-second samples (about one minute) and sanitizes invalid readings; history is kept only in memory and is not written to disk.

## v0.34

Added Settings controls to show or hide individual cards in the floating System Monitor. Preferences persist locally, unknown saved card names are ignored safely, and a fresh install starts with all supported cards enabled.

## v0.58

Added a confirmation-protected recording cleanup action. It moves the selected audio/video file and any matching transcript or subtitle sidecars to macOS Trash together, then refreshes the history. Tests verify sidecar discovery for both audio-only and screen recordings.

## v0.59

Added batch video compression for selected or all MOV, MP4, and M4V tray items. MacNotch exports medium-quality MP4 copies into a chosen folder and keeps a result only when it is smaller than the source; repeated inputs are deduplicated, output collisions get numbered names, unsupported or missing files are skipped, and originals remain untouched. A generated-video integration check verifies the exported MP4 is playable and smaller than its source, as well as source retention and collision safety.

## v0.60

Added batch conversion of selected or all WAV, AIFF, AIF, and CAF tray audio into AAC-based M4A copies. Duplicate sources are converted once, collisions are numbered, invalid or missing files are reported, output is kept only when smaller than the source, and originals are preserved. A generated PCM WAV fixture verifies the result is a playable smaller M4A with an audio track.

## v0.57

Added an explicit **New Event** composer to Calendar & Tasks. Set the event title, start time, and duration; MacNotch writes it to the default Calendar only when Create Event is pressed, and reloads the upcoming-event list if it was already loaded. The Calendar permission prompt and usage description now cover both reading and creating. Existing reminder creation stays separate.

## v0.56

Added keyboard navigation to the App Launcher: Up/Down move through filtered results with wraparound and Return opens the selected app. Search changes keep the selection valid. Deterministic checks cover forward/backward movement, wrapping, and empty results. Added a focused M4A writer check to verify both system audio and microphone can be saved as separate AAC tracks.

## v0.55

Added audio-only meeting capture alongside screen recording. Choose system audio and/or the microphone, save a local M4A without capturing screen pixels, then create on-device transcripts and timed subtitles through the existing workflow. The recording library and file picker now include M4A recordings; tests verify audio recordings appear in the library and use the same transcript/subtitle sidecar naming.

## v0.54

Added batch conversion of selected or all tray images into lossless PNG copies. PNG exports retain full pixel dimensions, alpha transparency, and image orientation while removing GPS location metadata; collisions receive numbered filenames and originals are unchanged. Generated-image tests verify format, dimensions, duplicate-source handling, collision safety, and source retention.

## v0.53

Added batch image compression from the file tray and floating shelf. Selected images (or all tray images when none are selected) become smaller JPEG copies in a chosen folder; unsupported files are reported, same-named outputs get numbered filenames, existing files are preserved, and all originals remain unchanged. Generated-image checks cover duplicate sources, name collisions, unsupported files, dimensions, and source retention.

## v0.52

Meeting transcription now also exports word-timed SRT subtitles from Apple's local speech segments, next to the plain text transcript. The recording list exposes existing captions, and deterministic formatter checks cover timestamps, invalid cues, line breaks, numbering, and empty results.

## v0.51

Added Core Audio output device discovery and switching, supported software volume and mute controls, unsupported-control explanations, one-second refresh for external route changes, and deterministic volume-clamping checks.

## v0.50

Added a local searchable app launcher with persisted favorites, direct app opening, refresh, and deterministic tests for bundle discovery, hidden paths, nested apps, de-duplication, and sorting.

## v0.49

Added a local meeting recording library that lists the 50 newest movie files, their dates and sizes, and direct playback/transcription actions. Existing transcript sidecars open from the same row. A deterministic check covers supported media types, newest-first ordering, hidden files, directories, file sizes, transcript paths, and list limits.

## v0.48

Added a local teleprompter with a persistent script editor, smoothly adjustable floating reader, pause/resume/replay and reset controls, text-size and scroll-speed adjustment, mirror mode, and the global Control–Option–P shortcut. Playback timing logic has deterministic pause/resume and speed-clamp tests.

## v0.47

Expanded Focus into a Pomodoro cycle: a 25-minute focus session automatically starts a 5-minute break, with a 15-minute break after every fourth completed focus. Break completion returns to a ready state, and Live Activities show the current phase and countdown.

## v0.46

Improved the floating file shelf with a one-click Quick Look preview and made the selected-item count visible in both tray surfaces. Removed duplicate Quick Look commands from the main tray menu.

## v0.35

Added an Apple Music current-playlist preview in the floating player. It reads at most 15 track rows, marks the current track, and lets the user explicitly select one to play. Spotify does not expose equivalent playlist data through its installed AppleScript dictionary, so this view is Apple Music-only.

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
