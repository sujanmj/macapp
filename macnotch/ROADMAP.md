# MacNotch feature parity tracker

This is a build tracker for an original MacNotch implementation. The reference product's public handbook currently lists 42 Droplets plus the core surfaces below; its catalog changes over time. This tracker is based on the public [Droplet catalog](https://getdroppy.app/docs/droplets), [live-activity guide](https://getdroppy.app/docs/live-activities), and [core feature handbook](https://getdroppy.app/docs).

Status means **complete** only after the user-facing workflow is implemented, tested, and documented. **Partial** means a smaller MacNotch feature exists but does not yet cover the reference workflow. Full visual/source duplication is not the goal; equivalent, reliable workflows are.

## Core surfaces

| Surface | Status | Notes |
| --- | --- | --- |
| Dynamic notch and island | Partial | Compact black notch, glass panel, saved accent colors, fullscreen preference, and external-display islands with live CPU/RAM/network cards; configurable per-display widgets and layouts remain. |
| File tray | Partial | Persistent path list, file picker/drop, search by file or parent folder, visible-result selection, Quick Look thumbnails and full in-app preview, drag-out, open/reveal/remove, ZIP, collision-safe copy to chosen/recent folders; destination-aware transient shelf and quick actions still needed. |
| Floating file tray | Partial | Separate shelf with drop-in, drag-out, multi-select copy, Quick Look preview, visible selection count, and pointer shake-to-reveal; auto-hide, multiple trays, and destination-aware quick actions remain. |
| Quick Actions | Partial | Finder add-to-tray service, batch smaller JPEG and PNG copies, selected/all multi-file sharing, recent copy destinations, and PDF merging; configurable action recipes and broader file types remain. |
| File Transform | Partial | Local ZIP creation, batch image downsampling to collision-safe JPEG copies, full-resolution PNG conversion with GPS metadata removal, multi-PDF merge, batch medium-quality MOV/MP4/M4V-to-MP4 copies, 10-fps animated GIFs from up to 15 seconds of video, shared-range video trimming, and WAV/AIFF/AIF/CAF-to-M4A conversion; broader audio format support remains. |
| Clipboard | Partial | Searchable session history and explicitly saved local pins with privacy exclusions; cross-device sync still needed. |
| Live Activities | Partial | MacNotch-owned music, focus, tray, recorder, frontmost-app, and explicitly loaded next-event/reminder statuses; system and third-party feeds still needed. |
| Floating player | Partial | Resizable floating Apple Music/Spotify mini-player with seeking, playback controls, artwork, Apple Music lyrics, and a 15-track current-playlist preview; deeper queue controls and Spotify lyrics remain. |
| Lock screen | Planned | Lock-screen display surfaces and media/focus cards. |
| Cloud sharing | Planned | Temporary file links with expiry and account/security design. |
| iPhone sync/widgets | Planned | Pairing, encrypted sync, iOS widgets, and Live Activities. |

## The current 42-item catalog

| Category | Feature | Status |
| --- | --- | --- |
| Productivity | Alfred Workflow | Planned |
| Productivity | App Launcher | Partial — local searchable application catalog, pinned favorites, and keyboard navigation; custom actions and launcher workflows remain |
| Productivity | Termi-Notch | Planned |
| Productivity | Calendar and Tasks | Partial — on-demand events, explicit event creation, reminder creation, and explicit completion; editing tasks and advanced calendar controls remain |
| Productivity | Pomodoro | Partial — 25-minute focus, automatic 5-minute breaks, and a 15-minute break after each fourth focus; custom durations and cycle history remain |
| Productivity | Teleprompter | Partial — local saved script, adjustable floating scroll reader, pause/resume, mirror mode, and global shortcut; script formatting and voice-follow scrolling remain |
| Productivity | Meetings | Partial — local display or selected-window/system/mic recording, audio-only M4A capture, explicit on-device transcript and timed SRT captions, recent recording library, and confirmed Trash cleanup with sidecars; third-party controls and live transcripts remain |
| Productivity | Notes | Partial — local quick note only |
| Productivity | Thunderstorm launcher | Planned |
| Productivity | Obsidian | Planned |
| Productivity | Weather | Planned |
| Productivity | Action Ring | Planned |
| Productivity | DropClip | Planned |
| Productivity | Xcode Builds | Planned |
| Productivity | Things 3 | Planned |
| Media | Spotify | Partial — playback controls, seeking, and album artwork; queue and lyrics remain |
| Media | Audio Control | Partial — Core Audio output device switching, software volume, mute when supported, and current route display; hardware-only output volume and per-app routing remain macOS-controlled |
| Media | Apple Music | Partial — playback controls, seeking, album artwork, available track lyrics, and a playable preview of the current playlist's first 15 tracks; full queue management remains |
| Media | Lyrics | Partial — Apple Music-provided track lyrics in the floating player; synchronized line timing and Spotify lyrics remain |
| Media | Kaset / YouTube Music | Planned |
| AI | Remove Background | Planned |
| AI | Voice Transcribe | Partial — MacVoice is separate and not integrated into MacNotch |
| AI | Coding Agents | Planned |
| AI | MCP tools | Planned |
| Capture | Element Capture | Partial — display/window screenshot, drag crop, local OCR, freehand markup; more editing tools remain |
| Capture | Camera | Planned |
| Capture | Text Capture / OCR | Planned |
| Files | Finder Services | Partial — Finder Services menu action adds selected items to tray; contextual Quick Actions and broader provider compatibility remain |
| Files | Temporary Cloud Sharing | Planned |
| Files | LocalSend | Planned |
| System | Window Snap | Partial — snaps the frontmost app's focused window to left/right half, maximize, or center with Accessibility permission; multi-window layouts and per-display positioning remain |
| System | Notifications | Planned |
| System | Stay Awake | Partial — Home can temporarily prevent idle display/system sleep for 1, 2, or 4 hours, with automatic expiry and a manual stop; lid-close and emergency sleep remain macOS-controlled |
| System | LiquidMouse | Planned |
| System | Thaw menu-bar management | Planned |
| System | Mechey keyboard sounds | Planned |
| System | System Stats | Partial — configurable CPU/RAM trends, top process, disk, network, and battery status in the floating monitor; GPU readings remain |
| System | Emoji Picker | Partial — opens Apple's native Emoji & Symbols palette from Home or Control–Option–E; a built-in recents/favorites picker remains |
| System | Lid Fold | Planned |
| System | Cleaner | Planned |
| System | Window Switcher | Planned |
| System | Dock Previews | Planned |
| System | CleanMyMac integration | Planned |

## Release sequence

1. **Core shelf and widgets:** harden drop targets and file lifetimes; add configurable side widgets and live system cards.
2. **Capture and meetings:** recording preview and controls, microphone/system audio behavior, local on-device transcription, richer image editing, then per-app meeting controls with explicit permission and app-specific handling.
3. **Media and activities:** queue/lyrics/floating player, activity arbitration, battery/network/device/notification activity sources.
4. **Productivity and file actions:** calendar/tasks, launcher/action ring, conversion/compression, Finder actions, teleprompter, and local send.
5. **Integrations and polish:** AI agents/MCP, Obsidian/Things/Kaset, window management, and optional iPhone sync.

Every increment still needs a macOS build, meaningful checks, permission/device testing for the APIs involved, an updated tracker, and a verified GitHub installer before it is called ready.
