# MacPulse v0.9 — Free Mac utility & desktop widget

Independent macOS 14+ Apple Silicon utility inspired by the categories of [MacKeeper](https://mackeeper.com/), **not affiliated** and not an antivirus/VPN service.

## What's working in V0.6

- Native **WidgetKit desktop widget** in small, medium and large sizes. Customize primary memory/storage metric and whether Clean and VPN action links are displayed in medium/large layouts.
- SwiftUI desktop dashboard and menu-bar quick stats for physical RAM and disk usage.
- **Reversible Safe Cleanup**: scans *only* `~/Library/Logs` for `.log` and `.txt` files older than 14 days (max 50 MB each), previews findings, asks for confirmation, and moves selected eligible files to Trash. No cache destruction, password clearing, system-file modification, `sudo`, or automatic deletion.
- **Exact Duplicate Finder**: choose a folder; compare same-sized files using SHA-256, report duplicate groups read-only (limit 3,000 files; individual files under 200 MB). No automatic deletion.
- **Memory cleaner**: lists normal user-facing apps with approximate resident memory; user can request a graceful quit after confirmation (no force-quit, no RAM purge).\n- **Optional Cloudflare WARP integration**: if you separately install and activate Cloudflare's official free WARP macOS client, MacPulse can use its existing `warp-cli` executable to check status and request Connect/Disconnect. Cloudflare operates the tunnel; it is not hosted, built, bundled or provided by MacPulse.\n- **VPN controls**: lists compatible VPN services already configured in macOS using `scutil --nc list`, offers Connect/Disconnect and Network Settings shortcut. This **does not create a free VPN service** or route traffic without an existing configured server/provider. Cloudflare WARP's separate free client is linked as an option.
- Shortcuts to Applications, Login Items & Extensions, Privacy & Security, and GitHub releases.

## Storage Analyzer (introduced in v0.3)

Open **Storage Analyzer** from the navigation sidebar or menu bar. Explicitly choose a folder (for example Downloads, Documents or a project directory). MacPulse scans at most 20,000 entries without following symlinks, inspecting hidden files or descending into app packages. It displays measured bytes by file type and the largest individual files. Adjust the minimum size slider; select only specific files you want to discard, then click **Move Selected to Trash**. A second confirmation shows how much space was selected. Immediately before recycle, each selected file is checked again against the chosen folder and its original size. Nothing is permanently deleted or cleaned automatically.

This is deliberately *not* a full-disk usage map: scans skip protected/unreadable paths, packages, hidden files, and anything beyond the safety limit. The measured file sizes can differ from disk allocation or total volume usage.

## Install and add the desktop widget

Install Xcode and XcodeGen (`brew install xcodegen librsvg`), or download a GitHub DMG.

```sh
git clone https://github.com/sujanmj/macapp.git
cd macapp/macpulse
bash scripts/package-dmg.sh
```

Open `MacPulse-v0.9.dmg`, drag `MacPulse.app` to Applications and launch it. To place the native widget on your desktop: right-click the macOS desktop → **Edit Widgets** → search **MacPulse** → add **MacPulse · Memory & System**. The widget refreshes around every 5 minutes, subject to macOS WidgetKit scheduling. Click **Clean** to open the app's memory review (graceful quitting of individually confirmed user apps), or **VPN** to open VPN controls. These are launch links, **not background actions**; they do not silently clean or establish a VPN.

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

V0.6: CPU tick activity, battery level/state, public thermal state, hardware network traffic with in-app time series charts.
V0.6: AppIntent-configurable WidgetKit panels, with three sizes, a primary memory/storage metric, and optional quick-action links.
V0.6: read-only verification of FileVault, Firewall, Gatekeeper, SIP and automatic update checks. V0.7+: VPN/network improvements, app review and developer tools. No independent VPN server or unverified antivirus claims.

MIT licensed. Please evaluate cleanup selections before confirming.

## Performance dashboard (new in v0.6)

Click **Performance** in the sidebar to view measured CPU activity, CPU history, battery percentage and charging status, thermal pressure as reported by `ProcessInfo.thermalState`, and estimated upload/download rates for hardware `en*` interfaces.

- CPU usage is measured by differences in the public Mach host CPU tick counters. The first measurement displays **Sampling…** until a second sample arrives, normally after 15 seconds.
- Network speeds are differences in byte counters of physical `en*` interfaces across samples. They are not packet inspection; no traffic contents or IP addresses are collected or stored. Traffic through VPN/virtual/tunnel interfaces may be missing or double represented elsewhere, so these values can differ from Activity Monitor.
- Battery charge and charging state come from `pmset -g batt` and may be unavailable on a desktop Mac.
- macOS thermal state is a coarse power-management indicator, not a literal CPU temperature. MacPulse does not claim to measure GPU utilization, fan RPM, sensor temperatures, or accurate macOS memory pressure.
- The app keeps up to 120 CPU/network samples **only in memory**, approximately 30 minutes at 15-second intervals. There is no background analytics, storage or upload. Charts reset when the app quits.

As before, this monitoring never force-quits applications, purges RAM, or deletes files without user review.

## Customizable widgets (new in v0.6)

After installing the updated app, right-click the desktop and choose **Edit Widgets**, then add a **MacPulse · Memory & System** widget in the small, medium or large layout. Right-click a placed widget and choose **Edit Widget**:

- **Primary metric:** Memory in use (estimated) or storage used. Small and medium sizes emphasize this choice; the large layout shows both.
- **Show quick actions:** Turn the Clean and VPN action links on or off on medium and large layouts. These buttons open MacPulse's review or connection controls and **never** silently delete data or establish a VPN.

The small widget has one tap target, opening the configured metric in MacPulse. Medium/large widgets provide separate links. WidgetKit refreshes under macOS scheduling, so these are periodic snapshots (approximately 5 minutes requested), not live CPU-speed panels. The full MacPulse app supplies faster 15-second CPU/network updates.

Configuration is stored by the system via AppIntents, not sent to a server. The widget does not need a new privacy entitlement.

## Security Center (new in v0.6)

Click **Security Center** → **Run Security Checks**. MacPulse reads these statuses using built-in, fixed macOS tools (read-only, no administrator password required):

- **FileVault:** `fdesetup status`
- **Application Firewall:** `socketfilterfw --getglobalstate`
- **Gatekeeper assessments:** `spctl --status`
- **System Integrity Protection (SIP):** `csrutil status`
- **Automatic software update checking:** `softwareupdate --schedule`

Checks run only on request. Results are shown as Enabled, Review, or Unavailable; unavailable is **not** treated as disabled. Security checks link to the relevant macOS System Settings pages. Information may differ from current platform UI or enterprise device policies; confirm there before changing anything.

**Not antivirus:** This does not scan downloaded apps for malware, detect spyware, audit TCC permissions, verify app signatures, or guarantee that a Mac is secure. No Apple security protections are turned off, no recovery keys are read, and no system settings are modified automatically.

## Network Center (new in v0.7)

The VPN tab now includes a read-only route status from Apple's Network.framework, reports Wi-Fi/Ethernet/other interface type, IPv4/IPv6 availability, metered interfaces and Low Data Mode. A **Resolve** button performs a hostname DNS lookup only when explicitly requested, using the Mac's configured DNS resolver; no telemetry or packet capture is uploaded to MacPulse. The DNS response is shown with elapsed time and returned IP addresses.

The system VPN list and free-tier Cloudflare WARP integration **still require a user-configured tunnel or separately installed official Cloudflare client**. MacPulse does not run a VPN server or proxy. Network.framework's route availability does not guarantee that Internet connectivity works.

## App Manager (new in v0.8)

The **App Manager** tab scans /Applications and ~/Applications read-only and displays each installed app's name, bundle ID, and version. You can reveal an app in Finder or explicitly **Trash…** an individual app bundle after confirmation. Running apps and the current MacPulse app cannot be trashed. This is a guarded move-to-Trash, **not** a complete uninstall: app support files, preferences, receipts and cloud data are not touched. If macOS denies access, use Finder to manage the app. Please close apps and save work before attempting removal.

The Homebrew cask tracker is **user-triggered**, read-only and uses existing local Homebrew data (`HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --cask --json=v2`). Results may be outdated; it does not download software, upgrade casks or cover non-Homebrew apps. Use official update channels for app security updates.

## Developer Tools (new in v0.9)

The **Developer Tools** tab scans well-known folders under your home directory, including Xcode DerivedData and Archives, CoreSimulator caches, Homebrew's cache, npm, Gradle and pip caches. It measures regular files (subject to a 20,000-entry bound per folder) and shows each folder's location, file count and estimated size. The built-in tool detection checks known executable locations for Git, Xcode, Homebrew, Docker, Terraform, kubectl, Node and Python; custom installations may be omitted.

Choose **Review Files…** to open that folder in Storage Analyzer, where you must select specific files and confirm moving them to Trash. **Show in Finder** never changes files. Do not delete Xcode Archives or simulator data unless you understand the implications; cached dependencies will need redownloading. MacPulse does not run `docker system prune`, `brew cleanup`, `rm -rf`, `npm cache clean`, or any privileged cleanup command.
