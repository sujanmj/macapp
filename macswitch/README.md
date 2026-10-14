# MacSwitch v0.1

A native Windows-style individual-window switcher inspired by [AltTab](https://alt-tab.app/features). Independent code and identity, MIT licensed.

Allow **Accessibility** in the setup panel and click Recheck. Hold **Option**, press **Tab** to cycle individual accessible windows, then release Option to focus the selected window. Shift reverses, arrows navigate, Escape cancels, and clicking a card selects it. Minimized windows are included and restored on selection. A menu-bar Switch Windows command works without the hotkey. Quit other Option–Tab utilities before enabling this one. Input Monitoring may also be required by macOS; use the settings shortcut and relaunch if the event tap cannot start. Login is opt-in.

Window discovery uses public Accessibility APIs with per-app timeouts on a background task. The keyboard callback stays short; early Option release and repeated Tab presses are queued while discovery completes. App activation history determines ordering, with the current app/focused window first. Only the intended Option–Tab combination, switcher navigation and Escape are intercepted. A disabled event tap cancels the overlay and re-enables itself. No screenshots or unrelated keystrokes are recorded.

Limits: app icons/titles rather than live window thumbnails; bounded inventory of regular apps and standard/dialog windows. Custom accessibility implementations, secure input and windows on other Spaces/full-screen desktops may limit enumeration/focus. No window closing, force-quit, private window-server APIs, or system changes. This is an initial switcher, not full AltTab feature parity.

## Build and checks

`bash scripts/package-utility.sh MacSwitch` from repo root; Xcode/XcodeGen, macOS 14+. Universal Apple Silicon/Intel DMG plus checksum; ad-hoc signed and unnotarized. Desktop Utilities CI publishes a beta installer after all four builds and checks pass; see [downloads](downloads/README.md).

Device test: multiple windows within one app and across apps; repeated and reverse cycling; release Option immediately during discovery; Escape; minimized/hidden windows; inaccessible/hung apps; Accessibility denial/revocation; other Spaces; conflicting shortcut tools. Ensure ordinary Tab/Cmd-Tab remain unaffected and no window is focused after cancellation.
