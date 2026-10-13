# MacPulse v0.2 — Free Mac utility & desktop widget

Independent macOS 14+ Apple Silicon utility inspired by the categories of [MacKeeper](https://mackeeper.com/), **not affiliated** and not an antivirus/VPN service.

## What's working in V0.2

- Native **WidgetKit desktop widget** displaying estimated memory in use and links **Clean** and **VPN**.
- SwiftUI desktop dashboard and menu-bar quick stats for physical RAM and disk usage.
- **Reversible Safe Cleanup**: scans *only* `~/Library/Logs` for `.log` and `.txt` files older than 14 days (max 50 MB each), previews findings, asks for confirmation, and moves selected eligible files to Trash. No cache destruction, password clearing, system-file modification, `sudo`, or automatic deletion.
- **Exact Duplicate Finder**: choose a folder; compare same-sized files using SHA-256, report duplicate groups read-only (limit 3,000 files; individual files under 200 MB). No automatic deletion.
- **Memory cleaner**: lists normal user-facing apps with approximate resident memory; user can request a graceful quit after confirmation (no force-quit, no RAM purge).\n- **Optional Cloudflare WARP integration**: if you separately install and activate Cloudflare's official free WARP macOS client, MacPulse can use its existing `warp-cli` executable to check status and request Connect/Disconnect. Cloudflare operates the tunnel; it is not hosted, built, bundled or provided by MacPulse.\n- **VPN controls**: lists compatible VPN services already configured in macOS using `scutil --nc list`, offers Connect/Disconnect and Network Settings shortcut. This **does not create a free VPN service** or route traffic without an existing configured server/provider. Cloudflare WARP's separate free client is linked as an option.
- Shortcuts to Applications, Login Items & Extensions, Privacy & Security, and GitHub releases.

## Install and add the desktop widget

Install Xcode and XcodeGen (`brew install xcodegen librsvg`), or download a GitHub DMG.

```sh
git clone https://github.com/sujanmj/macapp.git
cd macapp/macpulse
bash scripts/package-dmg.sh
```

Open `MacPulse-v0.2.dmg`, drag `MacPulse.app` to Applications and launch it. To place the native widget on your desktop: right-click the macOS desktop → **Edit Widgets** → search **MacPulse** → add **MacPulse · Memory & VPN**. The widget refreshes around every 5 minutes, subject to macOS WidgetKit scheduling. Click **Clean** to open the app's memory review (graceful quitting of individually confirmed user apps), or **VPN** to open VPN controls. These are launch links, **not background actions**; they do not silently clean or establish a VPN.

The widget extension is embedded inside `MacPulse.app`. If it does not appear immediately, reopen the Edit Widgets gallery after restarting the app, or log out and back in.

## Privacy, safety and limits

- No account, subscriptions, network telemetry or analytics. External links only open when selected.
- Memory *in use* is an approximation (active + wired + compressed pages); macOS manages RAM and caching itself. MacPulse intentionally does not force-purge system memory, because doing so is rarely beneficial.
- Cleaner moves eligible files to Trash after explicit confirmation; empty Trash separately if desired.
- Duplicate detection is exact file hashing only, not similar-photo AI classification.
- VPN **requires** a server and credentials/service. This release only controls existing compatible macOS VPN profiles. Cloudflare's independently operated free-tier WARP service can be used when its official client is installed. A wholly independent globally hosted VPN service cannot be delivered by an app alone, and a native VPN extension needs Apple entitlements and infrastructure.
- No antivirus engine, real-time anti-malware, adware monitoring, browser blocker, password breach checks, app updater integrations or unattended uninstaller yet. These are future milestones, not working features.
- Releases are **ad-hoc signed but not Apple Developer ID signed or notarized**; macOS may require explicit user approval when installing the DMG. The GitHub Release includes a SHA-256 manifest for verification.

## Roadmap

V0.3: richer per-process memory and disk diagnostics, duplicate review/trash action, application inventory.
V0.3: permission-based diagnostics, performance and login-items report, optional browser extension research.
V0.4+: optional self-hosted VPN tunnel integration **only** with valid VPN provider/server configurations and Apple signing entitlements; no claims of free server bandwidth.

MIT licensed. Please evaluate cleanup selections before confirming.
