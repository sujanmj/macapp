# MacNotch feature parity tracker

This is a build tracker for an original MacNotch implementation. The reference product's public handbook currently lists 42 Droplets plus the core surfaces below; its catalog changes over time. This tracker is based on the public [Droplet catalog](https://getdroppy.app/docs/droplets), [live-activity guide](https://getdroppy.app/docs/live-activities), and [core feature handbook](https://getdroppy.app/docs).

Status means **complete** only after the user-facing workflow is implemented, tested, and documented. **Partial** means a smaller MacNotch feature exists but does not yet cover the reference workflow. Full visual/source duplication is not the goal; equivalent, reliable workflows are.

## Core surfaces

| Surface | Status | Notes |
| --- | --- | --- |
| Dynamic notch and island | Partial | Compact black notch, glass panel, saved accent colors, fullscreen preference; notchless display island still needed. |
| File tray | Partial | Persistent path list, file picker and drop, drag-out, open/reveal/remove, ZIP, collision-safe copy to a chosen or recent folder; destination-aware transient shelf and quick actions still needed. |
| Floating file tray | Partial | Separate shelf with drop-in, drag-out, multi-select copy, and pointer shake-to-reveal; auto-hide, multiple trays, and destination-aware quick actions remain. |
| Quick Actions | Partial | Finder add-to-tray service, smaller JPEG copy, selected/all multi-file sharing, recent copy destinations, and PDF merging; configurable action recipes and broader file types remain. |
| File Transform | Partial | Local ZIP creation, image downsampling to JPEG, and multi-PDF merge; audio/video transforms remain. |
| Clipboard | Partial | Searchable session history and explicitly saved local pins with privacy exclusions; cross-device sync still needed. |
| Live Activities | Partial | MacNotch-owned music, focus, tray, recorder, and frontmost-app statuses; system and third-party feeds still needed. |
| Floating player | Partial | Resizable floating Apple Music/Spotify mini-player with seeking and playback controls; queue, artwork, and lyrics remain. |
| Lock screen | Planned | Lock-screen display surfaces and media/focus cards. |
| Cloud sharing | Planned | Temporary file links with expiry and account/security design. |
| iPhone sync/widgets | Planned | Pairing, encrypted sync, iOS widgets, and Live Activities. |

## The current 42-item catalog

| Category | Feature | Status |
| --- | --- | --- |
| Productivity | Alfred Workflow | Planned |
| Productivity | Termi-Notch | Planned |
| Productivity | Calendar and Tasks | Partial — on-demand events, reminder creation, and explicit completion; editing tasks and advanced calendar controls remain |
| Productivity | Pomodoro | Partial — basic Focus timer exists |
| Productivity | Meetings | Partial — local display or selected-window/system/mic recording and explicit on-device transcript; third-party meeting controls still needed |
| Productivity | Notes | Partial — local quick note only |
| Productivity | Thunderstorm launcher | Planned |
| Productivity | Obsidian | Planned |
| Productivity | Weather | Planned |
| Productivity | Action Ring | Planned |
| Productivity | Teleprompter | Planned |
| Productivity | DropClip | Planned |
| Productivity | Xcode Builds | Planned |
| Productivity | Things 3 | Planned |
| Media | Spotify | Partial — playback controls and seeking; queue/art/lyrics still needed |
| Media | Apple Music | Partial — playback controls and seeking; queue/art/lyrics still needed |
| Media | Lyrics | Planned |
| Media | Audio Control | Planned |
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
| System | Window Snap | Planned |
| System | Notifications | Planned |
| System | Stay Awake | Planned |
| System | LiquidMouse | Planned |
| System | Thaw menu-bar management | Planned |
| System | Mechey keyboard sounds | Planned |
| System | System Stats | Partial — CPU, RAM, top process, disk, and network; GPU, battery, graphs, and configurable widgets needed |
| System | Emoji Picker | Planned |
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
