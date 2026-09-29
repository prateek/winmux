# Research: reading tabs from browsers and tabbed editors

Type: research
Status: resolved

## Question

Can WinMux list the tabs inside a window (title, and URL or file path where there is one), fast enough to use them in Filters and in a Picker's type-to-search, and switch to a chosen tab after focusing its window? Prateek uses Google Chrome and its derivatives (Brave, Arc, Edge, Vivaldi, Dia and similar), and editors such as VS Code and Cursor. For each family, find the mechanisms, their costs and their failure modes:

- **Chromium browsers:** AppleScript/JXA tab listing and switching (`tabs of windows`, `active tab index`), and which derivatives keep Chrome's scripting dictionary. The accessibility tree (`AXManualAccessibility` / `AXEnhancedUserInterface`, what the tab strip exposes, read cost per window). Chrome DevTools Protocol, if a remote-debugging port is available. How a scripted window maps back to a WinMux window (`CGWindowID`, AX window, title plus bounds).
- **Electron editors (VS Code, Cursor):** whether the AX tree exposes editor tabs, whether the window title carries the active file or workspace, and any CLI, extension or IPC route (for example a small extension that reports open editors). Also how multiple windows per app map to workspace folders.
- **Native AppKit tabbed apps (Finder, Terminal, TextEdit, and any app using `NSWindow` tabbing):** each tab is a separate `NSWindow`; how the `AXTabGroup` children expose titles (see AltTab's `tabGroupObservation`, GPL-3, design only), and how WinMux sees those windows today.
- **Other tabbed apps worth a line:** Ghostty, iTerm2, Zed, Xcode, Obsidian.

Also cover: TCC permissions each route needs (Automation per target app, Accessibility, and none for CDP) and whether the prompt can be triggered deliberately at setup; latency for about 50 windows and several hundred tabs; staleness and caching (read on Picker open versus event-driven); and how prior art does it (Raycast's browser-tab search, Alfred, Contexts, Witch, AltTab's refusal in issue #5155). Deliverable: a per-app-family table of mechanism, permission, cost, and what WinMux would expose as Filter attributes (for example `w.tabs` as a list of title and url or path).

## Answer

Findings: [research/18-reading-app-tabs.md](../research/18-reading-app-tabs.md).

- Yes for most of Prateek's apps, but through a different route per family, and never as a live read inside a Filter. `w.tabs` (a `list<Tab>` of `title`, `url`, `path`, `active`, `index`) is a per-window cache. It's filled off the main thread, refreshed when a Picker opens (stale values show while the refresh runs), and fetched only when some binding's CEL or type-to-search actually uses tabs (§6, §9).
- Chrome and most derivatives (Brave, Edge, Vivaldi, Opera, Comet, Helium) share Chrome's AppleScript dictionary: tab `title` and `URL`, window `name`, `bounds` and a writable `active tab index`. Arc and Dia each have their own dialect. Bulk reads cost hundreds of milliseconds per browser, need an Automation grant per browser, and map back to WinMux windows by title plus bounds, because Chrome's window `id` isn't a `CGWindowID` (§1).
- The accessibility tree gives Chrome tab titles but never URLs. `AXEnhancedUserInterface` causes lag and fights WinMux's own frame-setting. CDP shows a Chrome consent dialog on every connection. Both are rejected (§1).
- VS Code, Cursor and Antigravity: the window title template and, probably, `AXDocument` give the active file and workspace for free. A full tab list needs either Electron accessibility mode, which isn't recommended, or a small extension that writes `tabGroups` to a file. Defer the extension (§2).
- Native `NSWindow` tabs (Finder, Terminal, TextEdit, Ghostty) are already separate WinMux windows, as inherited from AeroSpace #68. For those the work is grouping them by `AXTabGroup` and shared frame, not reading them. Ghostty, cmux, iTerm2 and Safari also have tab dictionaries with a select command (§3, §4).
- Permissions: WinMux needs `NSAppleEventsUsageDescription` and the apple-events entitlement. The Automation prompt can be triggered at setup with `AEDeterminePermissionToAutomateTarget`, but only while the target app is running (§5).
- Sidebar apps and extensibility (§10): Orca and cmux ship JSON CLIs (`orca terminal list --json` ran in about 0.1 s; `cmux events` streams changes), so the better design is a registered tab-provider interface. Providers are pull commands or `winmux tabs publish` pushes, all emitting one versioned schema with window-match hints, `group` for sidebar items, and `meta`. The built-in AppleScript and native-tab routes become the first providers.
- Build order: the provider interface first, then title plus `w.document`, then Chrome-dialect AppleScript, then native-tab grouping, then the Ghostty, Safari and iTerm2 dictionaries, then the editor extension if still needed (§9, §10). Fifteen open unverified claims have probes at the end of the findings.
