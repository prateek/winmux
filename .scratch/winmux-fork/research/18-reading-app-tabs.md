# Research 18: reading tabs from browsers and tabbed editors

Ticket: [18-research-reading-app-tabs](../issues/18-research-reading-app-tabs.md)
Date: 2026-09-29

## Answer in brief

WinMux can list tabs with title and URL or path for most of what Prateek runs, but no one mechanism covers them all, and none is cheap enough to call synchronously while a Filter evaluates.

- **Chromium browsers:** read tabs over AppleScript, which needs an Automation grant per browser. The accessibility tree only gives titles, and CDP asks for consent on every connection.
- **Native AppKit tabs:** WinMux already sees each tab as a window. The work there is grouping them, not reading them.
- **Ghostty, iTerm2, Safari, Terminal, cmux:** each has a scripting dictionary with tabs and a select command.
- **VS Code and other Electron editors:** only the active file is readable without an extension, through the window title and, probably, `AXDocument`.
- **Sidebar apps (Orca, cmux):** they ship JSON CLIs, so the recommended shape is a registered tab-provider interface. The built-in routes above become its first providers (§10).

So `w.tabs` is a per-window cache. It gets filled off the main thread, refreshed when a Picker opens (showing stale values while the refresh runs), and read by Filters only from memory.

## Sources and how they were read

- **App bundles on this Mac** (cited as `APP:<bundle>/<path>:<line>`): I read `Info.plist` and the `.sdef` scripting dictionaries under `Contents/Resources` for Google Chrome 154, Safari 26.4, Ghostty 1.3.1, iTerm2 3.7.2, Xcode 26.6, cmux 0.64, Alfred 5.8, and the Electron apps (VS Code 1.139, Antigravity, Obsidian 1.13.7, Orca, Superset). I also read Chrome's `Local State` `devtools` key and checked that `DevToolsActivePort` exists (first line only), plus the key shape of VS Code's `storage.json`. I didn't launch, script, or query any running app.
- **Apple**: the macOS SDK headers at `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk` (cited as `SDK:<framework>/<header>:<line>`), and `/System/Library/ScriptingDefinitions/CocoaStandard.sdef`. Apple's web docs on `NSAppleEventsUsageDescription` and the apple-events entitlement were read by a sub-agent.
- **Chromium** `chromium/chromium@7bc62b59` (cited as `CR:<path>:<line>`), **Electron** `electron/electron@dfcdfb14` (`EL:`), **VS Code** `microsoft/vscode@a58d8774` (`VSC:`), **Ghostty** `ghostty-org/ghostty@12752b2a` (`GT:`), **Raycast extensions** `raycast/extensions@707d8974` (`RX:`), **Hammerspoon** `Hammerspoon/hammerspoon@23e387e2` (`HS:`), **CDP** `ChromeDevTools/devtools-protocol@dc2ddf36` (`CDP:`), and **chrome-devtools-mcp** `@47c5b375`. A sub-agent read these on GitHub via `gh`. All of them are MIT, BSD, or Apache.
- **AltTab** `lwouis/alt-tab-macos@0d9d710` (2026-09-26), shallow-cloned to scratch (cited as `AT:<path>:<line>`). It's GPL-3, so I read it for design only and quote no code. Issue threads #5155, #2957, and #2771 were read on GitHub.
- **AeroSpace** issues #68 and #887 (upstream of WinMux), read via `gh`.
- **WinMux**: this repo at `ab8820b9` (cited as `WM:<path>:<line>`).
- **Not done**: no live probes and no measurements. I sent no Apple Events, set no AX attributes, and didn't connect to Chrome's debugging port. Every latency number below comes from someone else's measurement, and I say whose. Each claim that needs a live check is in the list at the end, with the probe to run.

## 1. Chromium browsers

### AppleScript: the workable route

Chrome's dictionary (`APP:Google Chrome.app/Contents/Resources/scripting.sdef`):

- **Window** (`:30-84`): `id` (text, `:43`), `name` ("the full title of the window", `:40`), `index`, `bounds` (`:49`), `minimized`, `visible`, `mode` (normal or incognito, `:76`), `active tab` (`:73`), and a writable `active tab index` (`:79`).
- **Tab** (`:206-213`): `id`, `title`, `URL`, `loading`. A tab has no `index` and no `select` command. To switch tabs, set the window's `active tab index`, which calls `TabStripModel::ActivateTabAt` (`CR:chrome/browser/ui/cocoa/applescript/window_applescript.mm:159-167`).
- **The window `id` is Chrome's `SessionID`, not a `CGWindowID`** (`CR:…/window_applescript.mm:111-112,128-129`). It's stable while the window lives, but not across restarts. `bounds`, `visible`, and `minimized` are forwarded to the `NSWindow` (`:306-313`).
- `execute javascript` exists but is gated by a per-profile "Allow JavaScript from Apple Events" setting (`CR:…/tab_applescript.mm:95`). WinMux doesn't need it.
- Chromium ships the dictionary in every build, with no branding gate (`CR:chrome/BUILD.gn:682-686`, `CR:chrome/app/app-Info.plist:164-167`).

**Which derivatives keep the dictionary**

| Browser | Dictionary | Evidence |
|---|---|---|
| Chromium, Brave | Chrome's | Chromium source above. brave-core has no sdef override. Raycast's Brave extension uses `tabs of w`, `URL`, `active tab index` (`RX:extensions/brave/src/actions/index.tsx:19-25,193`) |
| Edge, Vivaldi, Opera, Comet | Chrome's (closed source, so inferred from working scripts) | `RX:extensions/microsoft-edge/src/actions/index.ts:13-19,111`, `RX:extensions/vivaldi/src/actions/index.ts:16-22,113`, `RX:extensions/opera/src/actions/index.ts:16-22,87`, `RX:extensions/comet/src/actions/index.tsx:21-27,59` |
| Helium | Chrome's, plus a tab `select` command | `imputnet/helium-macos@24af3043:patches/helium/macos/applescript-tab-select-command.patch` |
| Thorium | Probably Chrome's (no sdef changes in its repo) | Unverified at runtime |
| Arc | Its own: `spaces`, and tabs with `id`, `title`, `URL`, `location` (topApp, pinned, unpinned), plus a `select` command | `RX:extensions/arc/src/arc.ts:44-56,115-128,206-221` |
| Dia | Its own: windows and tabs with `id`, `title`, `URL`, `isPinned`, `isFocused`, plus a `focus` command | `RX:extensions/dia/src/dia.ts:307-336,386-424`. The extension falls back from JXA to AppleScript because JXA sometimes returns zero tabs (`:210`) |

That's three dialects: Chrome's, Arc's, and Dia's. None of Arc, Dia, Edge, Brave, or Vivaldi is installed on this Mac, so I couldn't read their sdefs directly. The probe at the end reads them from disk without launching anything.

**Cost.** Raycast PR #29853 (closed, not merged) measured 1570 ms for 42 tabs across 2 Chrome windows when it looped over tabs one by one. Reading `title of tabs of w` and `URL of tabs of w` once per window brought that down to 250 ms. For 18 tabs in 3 windows it went from 1080 ms to 315 ms. Two things follow:

- Always use bulk property reads. Each Apple Event is one round trip.
- The whole-app form, `{title, URL} of tabs of every window`, is a handful of events per browser no matter how many tabs there are. The community Alfred workflow alfred-browser-tabs (epilande) uses the JXA equivalent (`windows.tabs.title()`; `epilande/alfred-browser-tabs@414523df:src/list-tabs.js`).

Nobody has published a number for several hundred tabs. My guess is that a bulk read of one browser costs roughly 100–500 ms. That's a guess and needs the latency probe below.

**Staleness.** Chrome sends no events over AppleScript. AX offers a title-change notification on the Chrome window, which fires only when the *active* tab's title changes. WinMux would have to subscribe to it; it doesn't today (see §6). Background tabs opening, closing, or navigating produce no signal. Freshness therefore comes from re-reading.

**Failure modes:**

- A `tell` to a browser that isn't running launches it (AppleScript Language Guide). Guard every send with `NSRunningApplication`.
- A busy browser can stall an Apple Event up to its timeout, so reads must run off the main thread with a short timeout.
- If Automation is denied, reads fail with `errAEEventNotPermitted` (-1743, `SDK:CoreServices/AE/AppleEvents.h:121`).
- Incognito windows show up with `mode = "incognito"`. Filters should probably be able to exclude them.

### Accessibility tree: titles only, and there's a side effect

- Chrome's tab strip is Views UI. Each tab has role `kTab`, which maps to `AXRadioButton` with subrole `AXTabButton`. The tab list maps to `AXTabGroup` (`CR:ui/accessibility/platform/ax_platform_node_cocoa.mm:144,984-989`). A tab's accessible name is its title plus state, with no URL (`CR:chrome/browser/ui/views/tabs/tab.cc:424,1014-1019`). The only URL in the AX tree is the omnibox, and only for the active tab.
- Any AX client that reads `accessibilityRole` on Chrome's `NSApp` turns on a lighter accessibility mode (`CR:chrome/browser/chrome_browser_application_mac.mm:479-494`). WinMux already does that as a window manager. My reading of the source is that the tab strip is exposed in that mode, but that's unverified.
- **`AXEnhancedUserInterface` turns on Chrome's full screen-reader mode**, after a 2-second debounce (`CR:…/chrome_browser_application_mac.mm:383-396,414-472`). This is documented to cause lag: a Chrome engineer traced up to 500 ms per frame to it (Rectangle #1065, crbug 1364487). It also animates AX moves and resizes. WinMux already turns it *off* around every frame set for exactly that reason (`WM:Sources/AppBundle/tree/MacAppFrameSetting.swift:27-38`), as Rectangle and yabai do. Turning it on to read tabs would fight WinMux's own layout loop. Don't.
- `AXManualAccessibility` is Electron-only. Chromium ignores it (`EL:shell/browser/mac/electron_application.mm:222-268`; `CR:…/app_shim_application.mm:37`).
- **Cost.** One AX round trip per child element, and Chrome's window has many nested children above the tab strip. AltTab caps a direct-child walk at 250 ms per window (`AT:src/macos/api-wrappers/AXUIElement.swift:342`), and even that walk was expensive enough that it now runs only as a backstop (`AT:src/switcher/state/TabReadPolicySpecs.md:10`).
- **Verdict:** the AX tree could give titles and the active index as a fallback when Automation is denied. It never gives URLs, and walking it costs more than one bulk Apple Event. Low priority.

### Chrome DevTools Protocol: rejected

- Since Chrome 136, `--remote-debugging-port` is ignored for the default profile directory (https://developer.chrome.com/blog/remote-debugging-port, 2025-03-17). Using it means running a second profile, which isn't Prateek's browser.
- Since Chrome 144, `chrome://inspect/#remote-debugging` lets a local client attach to the real profile. **Chrome shows a permission dialog on every connection** and a "controlled by automated test software" banner while attached (https://developer.chrome.com/blog/chrome-devtools-mcp-debug-your-browser-session). Prateek has this turned on: `Local State` has `devtools.remote_debugging.user-enabled: true`, and `DevToolsActivePort` names port 9222. It's there for chrome-devtools-mcp-style agents, but a per-connection dialog makes it unusable for a Picker that runs in the background.
- CDP data wouldn't be better anyway. `Target.getTargets` gives `title` and `url` plus `embedderData` (`tabStripIndex`, `tabActive`, `tabPinned`, `tabGroupId`; `CR:chrome/browser/devtools/chrome_devtools_manager_delegate.cc:363-401`), but no window id. Mapping a tab to a window needs `Browser.getWindowForTarget`, which returns a Chrome `windowId` and bounds (`CDP:pdl/domains/Browser.pdl:296-305`). That's the same bounds-matching problem AppleScript has.
- CDP needs no TCC permission, but an open port gives any local process full control of the profile, cookies included.

### Mapping a scripted window back to a WinMux window

WinMux identifies windows by `CGWindowID` (`WM:Sources/AppBundle/tree/Window.swift:5`). Chrome's AppleScript `id` is a SessionID, so the match has to go through observable properties:

1. **Title.** AppleScript `name` should be the same string as the AX window title WinMux already caches (`WM:Sources/AppBundle/ui/core/WindowTitleCache.swift:68-76`). Unverified: see the probes.
2. **Bounds.** AppleScript `bounds` is `{left, top, right, bottom}` in top-left-origin points. Compare it with the AX frame. WinMux parks windows at distinct monitor corners (see the thumbnails research), so the frame usually settles ties between windows with the same title, such as two New Tab windows. Two windows parked in the same corner with the same size and title stay ambiguous. In that case skip tab attribution for that window rather than guess.
3. **Memoize** SessionID → `CGWindowID` once matched, and invalidate on window destroy or a title-and-frame mismatch.

The same approach works for Arc, Dia, Ghostty, and cmux, whose ids are app-private strings (`APP:Ghostty.app/…/Ghostty.sdef:43`, `APP:cmux.app/…/cmux.sdef:40`).

Cocoa-scripting apps are different. Safari, Terminal, Finder, and Xcode inherit window `id` from `CocoaStandard.sdef:223-224`, which maps to `NSWindow`'s private `uniqueID`. It's widely assumed to equal `windowNumber`, and so the `CGWindowID`. If that holds, those apps map exactly. It's unverified.

## 2. Electron editors (VS Code, Cursor, Antigravity, Obsidian)

None of them ship a scripting dictionary. `NSAppleScriptEnabled` and `OSAScriptingDefinition` are absent from the Info.plist of VS Code, Antigravity, Obsidian, Orca, and Superset (all read on this Mac).

- **Window title.** VS Code's `window.title` template (`VSC:src/vs/workbench/browser/workbench.contribution.ts:864-890`) can carry `${activeEditorLong}`, `${activeFolderLong}`, `${rootName}`, `${rootPath}`, `${folderPath}`, `${activeRepositoryBranchName}`, and more. Prateek can set it to something parseable, for example `${rootName}${separator}${activeEditorMedium}`. That makes the workspace folder and active file free, through the title WinMux already reads. This is the cheapest route and needs no permission. Cursor and Antigravity are VS Code forks and should honour the same setting (unverified).
- **`AXDocument`.** VS Code calls `setRepresentedFilename(activeFile.fsPath)` whenever the active editor changes (`VSC:src/vs/workbench/electron-browser/window.ts:452-460`). AppKit normally exposes a represented filename as the window's `AXDocument` (`SDK:HIServices/AXAttributeConstants.h:1040`), a `file://` URL. If it does here, WinMux gets the active file's full path with one AX read per window and no configuration. It's unverified, so probe it. Xcode, TextEdit, Preview, and Zed may populate `AXDocument` the same way (Zed calls it at `zed-industries/zed:crates/gpui_macos/src/window.rs:1920`).
- **All open tabs via AX.** VS Code's tabs are DOM `role="tablist"` and `role="tab"` elements with an `aria-label` (`VSC:src/vs/workbench/browser/parts/editor/multiEditorTabsControl.ts:268,989,1824`). They reach the macOS AX tree only after Electron's accessibility mode is on, and that means setting `AXManualAccessibility` on the live process (`EL:…/electron_application.mm:222-268`). That switches on the full web accessibility tree for the whole app, which costs memory and CPU in the app for as long as it runs. It also changes the app's state, which this ticket rules out without Prateek's say-so. Walking a DOM-derived tree for the tab list also takes many round trips. Not recommended.
- **Extension.** `vscode.window.tabGroups.all` gives every tab with its input (`TabInputText.uri` and others), and `onDidChangeTabs` fires on every change (`VSC:src/vscode-dts/vscode.d.ts:11077,19166,19409-19428`). A roughly 50-line extension could write `{pid, windowTitle, workspaceFolders, tabs:[{label, uri, active}]}` to a file or unix socket under `~/.local/state/winmux/` on each change. That makes it event-driven and exact, and it needs no TCC permission. It has to be installed in each fork (VS Code, Cursor, Antigravity), which is fine because all three use the Open VSX or VSIX format. I found no existing extension that does this. It maps back to a WinMux window by pid plus window title, since the extension can read its own title via `window.title` config substitution. That last part is unverified.
- **`code --status`** lists windows and folders but scans the workspace files, which is slow (`VSC:src/vs/platform/diagnostics/node/diagnosticsService.ts:491-513`). Not usable per Picker open.
- **`storage.json` `windowsState`** holds each window's folder or workspace and its bounds. It's rewritten on window blur, and `openedWindows` is filled only when more than one window is open (`VSC:src/vs/platform/windows/electron-main/windowsStateHandler.ts:55,83-85,194-200`). The copy on this Mac had an empty `openedWindows` and was last written days ago with VS Code closed. It's a coarse workspace-folder hint at best, not a tab source.
- **Multiple windows per app.** Each VS Code window is one workspace folder or `.code-workspace`. With a title template that includes `${rootName}`, the folder falls out of the title. The extension route gives it exactly.
- **Obsidian.** `<vault>/.obsidian/workspace.json` holds the layout tree: `split` → `tabs` (`currentTab`) → `leaf{state{type, state{file}}}`, plus `active` and `lastOpenFiles`. It's a file WinMux could read with no permission. Obsidian writes it on layout change (I didn't time the debounce). The window title carries the active note and vault name. Whether pop-out windows appear in `workspace.json` is unverified. This Mac has no configured vault, so I couldn't read one.

## 3. Native AppKit tabbed apps (Finder, Terminal, TextEdit, Ghostty, Xcode, anything using `NSWindow` tabbing)

- **Each tab is its own `NSWindow`, and WinMux already registers them as windows.** AeroSpace issue #68, still open upstream, says "macOS accessibility API reports tabs as windows", reproducible in Finder, Terminal, TextEdit, and IntelliJ. #887 reports the same for Ghostty. WinMux enumerates windows from the app's `kAXWindowsAttribute` (`WM:Sources/AppBundle/tree/MacApp.swift:427`) and inherits that behaviour. WinMux has no native-tab handling (no `AXTabGroup` code; `git log` shows no fix). The upstream symptom is a blank tile where each background tab sits. Whether WinMux shows that today is unverified.
- **For this family the question is grouping, not reading.** The tabs are already Picker entries with titles and `CGWindowID`s, and focusing one through WinMux's `nativeFocus` should bring its tab forward (unverified per app). `w.tabs` for a native-tabbed window would be the sibling windows in the same group.
- **How AltTab groups them** (design only, GPL-3):
  - Only the *selected* tab's window exposes an `AXTabGroup` child, whose `AXTabButton` children carry the tab titles. AltTab reads direct children only, inside a 250 ms budget, and treats a partial read as "unknown", never as "standalone" (`AT:src/macos/api-wrappers/AXUIElement.swift:342-391`).
  - A tab button's window id resolves to the *parent* window, not the tab's own. So titles are matched to windows, and the `AXTabGroup` element's `AXUIElementID` works as a group token that every selected member reports (`AT:src/switcher/state/TabGroupResolverSpecs.md:8,16-24,37`).
  - Title matching can fail completely. Terminal's window title and tab title are built from different components (`:33`).
  - Background tabs appear in no CGS on-screen list. AltTab's fallback is geometry: same app, same size, one on a Space and the others Space-less (`:39-48`; `AT:src/windowserver/WsWindowStateSpecs.md:47-54`).
  - Reads cost one Mach round trip per child element. So AltTab reads tab groups only as a backstop behind events it already gets: WindowServer create and destroy for tab open and close, `AXMainWindowChanged` for tab switch, `AXTitleChanged` for rename. It re-reads at most 5 stale windows per show (`AT:src/switcher/state/TabReadPolicySpecs.md:10,27-44`).
- Hammerspoon's `hs.window:tabCount`/`focusTab` does the same `AXTabGroup` walk. Since Safari 14 it also handles an `AXGroup` exposing `AXTabs` (`HS:Hammerspoon/HSuicore.m:535-585,820-858`). `AXTabs` is a public attribute (`SDK:HIServices/AXAttributeConstants.h:1030`).
- **WinMux advantage.** WinMux's windows are all on one Space, parked in corners, so AltTab's Space-less heuristic doesn't carry over. WinMux does know every window's frame, and background tabs of one group should share the selected tab's frame. A simpler WinMux rule would be: same pid, same frame, exactly one on-screen, confirmed by the `AXTabGroup` button count on the visible one. That needs a prototype.

## 4. Other apps, one line each

- **Ghostty:** native `NSWindow` tabs (`GT:macos/Sources/Features/Terminal/TerminalController.swift:466-481`), so it's in §3. It also has a full scripting dictionary since 1.3.0: windows → tabs (`id`, `name`, `index`, `selected`) → terminals (`working directory`, `tty`, `pid`), plus `select tab` and `activate window` (`APP:Ghostty.app/Contents/Resources/Ghostty.sdef:41-94,195-211`). It's on by default via `macos-applescript` (`GT:src/config/Config.zig:3531-3539`). This is the cleanest tab source of any app checked, and it gives a cwd per tab, which works as a `path`.
- **cmux:** a Ghostty-derived dictionary with windows → "tabs" (cmux workspaces) → terminals with `working directory`, plus `select tab` (`APP:cmux.app/Contents/Resources/cmux.sdef:38-89,137-149`).
- **iTerm2:** AppleScript windows (`bounds`, integer `id` via `uniqueID`) → tabs (`current session`, `index`) → sessions (`name`, `tty`, text `id`), plus a `select` command (`APP:iTerm.app/Contents/Resources/iTerm2.sdef:95-177,499-575`). iTerm2 labels its AppleScript deprecated in favour of a Python API that's off by default and bootstraps its auth cookie over AppleScript (https://iterm2.com/python-api-auth.html). Both need Automation. Its tabs are custom-drawn, not `NSWindow` tabs.
- **Zed:** GPUI draws everything itself. A maintainer said in January 2026 that Zed had no accessibility support (zed-industries/zed#47186). AccessKit work landed later (#61925), but whether shipping Zed 1.20 exposes tabs is unverified. It has no scripting dictionary. What's left is the window title, plus `AXDocument` if its `setRepresentedFilename` call carries the active file.
- **Xcode:** its dictionary has `workspace document` and `source document` with `path`, and `window.document` (`APP:Xcode-26.6.0.app/Contents/Resources/Xcode.sdef:181,227,251-254`). Its editor tabs aren't in the dictionary. Xcode windows are ordinary `NSWindow`s, so native window tabbing, if used, falls under §3.
- **Obsidian:** Electron with no dictionary. Use `workspace.json` or the title (§2). The Local REST API plugin has `/active/` but doesn't list tabs.
- **Safari** (not asked, but installed): tabs have `name`, `URL`, `index`, `visible`, and the window has a writable `current tab` (`APP:Safari.app/Contents/Resources/Safari.sdef:11-13,41-58`). Its tab bar is also exposed through `AXTabs`.
- **Terminal.app:** tabs have `tty`, `processes`, `custom title`, and a writable `selected`. Its tabs are native `NSWindow` tabs (§3).

## 5. Permissions per route

| Route | TCC grant | Setup-time prompt? | Build change |
|---|---|---|---|
| Window title, `AXDocument`, `AXTabGroup` walk | Accessibility (already granted) | n/a | none |
| AppleScript to Chrome, Brave, Arc, Dia, Ghostty, iTerm2, Safari, and so on | Automation, **one grant per target app** | Yes. `AEDeterminePermissionToAutomateTarget(…, typeWildCard, typeWildCard, askUserIfNeeded: true)` shows the prompt on demand, but only while the target is running (otherwise `procNotFound`), and must be called off the main thread (`SDK:CoreServices/AE/AppleEvents.h:558-601`). With `askUserIfNeeded: false` it answers silently with `errAEEventWouldRequireUserConsent` (-1744), which is a cheap check to run on every Picker open. | WinMux's Info.plist needs `NSAppleEventsUsageDescription`, and under hardened runtime the `com.apple.security.automation.apple-events` entitlement. Neither is present today (`WM:resources/WinMux.entitlements`, `WM:resources/WinMux-Info.plist`). `WM:project.yml:56` enables hardened runtime. The installed dogfood build reports `flags=0x0` (no runtime), but add both anyway. |
| CDP via `chrome://inspect` toggle | none | Chrome's own per-connection dialog | none; rejected anyway |
| VS Code extension to file or socket | none | n/a | an extension, per editor fork |
| Obsidian `workspace.json` | none, unless the vault sits in a TCC-protected folder (Documents, Desktop, iCloud Drive), in which case Full Disk Access or Files & Folders | n/a | none |

Automation grants are tied to the signing identity. The dogfood release pipeline signs with a stable self-signed identity so Accessibility grants survive upgrades; Automation grants should survive the same way (unverified). A setup step could be `winmux doctor --grant-automation` or a Settings button. It would iterate running browsers and apps with a dictionary and call the determine-permission API with `askUserIfNeeded: true` for each.

## 6. Latency and staleness at about 50 windows and several hundred tabs

- **Picker open cannot wait on any of this.** Filters run per window per open (see the filter-language prototype), and the thumbnails research already settled on "render from cache, refresh after" (research 03 §5). Tabs follow the same pattern.
- **Budget per route** (unmeasured on Prateek's machine):
  - AX title and `AXDocument`: about 1 ms per window if the app is responsive, bounded by WinMux's existing title cache (5 s max age, stale-while-revalidate: `WM:Sources/AppBundle/ui/core/WindowTitleCache.swift:8,68-76`).
  - AppleScript bulk read: roughly 100–500 ms per browser app, based on Raycast's 250 ms for 42 tabs in 2 windows.
  - `AXTabGroup` walk: up to 250 ms per window in AltTab's budget.
  - Extension or `workspace.json` file: under 1 ms to read.
- **Event-driven where possible:**
  - Native tabs change with window create and destroy and focus events WinMux already receives.
  - The VS Code extension pushes on each change.
  - `workspace.json` can be watched with FSEvents.
  - Browsers push nothing. WinMux's AX title-change on the Chrome window covers only the active tab. WinMux currently subscribes to no `kAXTitleChangedNotification` at all (`WM:Sources/AppBundle/tree/AxWindow.swift:21-23`, `WM:Sources/AppBundle/tree/MacApp.swift:82`).
- **Cache policy for scripted apps.** Keep one cache entry per app (pid): SessionID → `CGWindowID` map, tabs per window, `readAt`.
  - Refresh on Picker open, and render first with whatever is cached.
  - Refresh on the app's deactivation, since that's when Prateek has just finished changing its tabs.
  - Refresh on title change of any of its windows, debounced. This needs a new `kAXTitleChangedNotification` observer.
  - Background refresh no more than once every 30 s while the app is running, and skip that when no Picker binding reads `w.tabs`. The CEL AST says whether any Filter references `w.tabs`. Type-to-search that includes tab titles counts as a reader.
  - After a refresh, re-run matching so the Picker updates in place, the way thumbnails do.
- **Picker open to first frame:** unaffected. Tab-derived matches may arrive one refresh later. For the strip (MRU cycling) that's harmless. For type-to-search in the grid, a query typed within the first few hundred milliseconds could miss a tab opened since the last refresh.

## 7. Prior art

- **Raycast.** A separate extension per browser, all AppleScript or JXA, none using CDP (`RX:extensions/google-chrome/src/actions/index.tsx:7-30,121-131`, and Brave, Edge, Vivaldi, Opera, Comet, Arc, Dia, Orion as cited in §1). The generic "Browser Tabs" extension probes `name` (WebKit) and falls back to `title` (Chromium), and guards with `if running` (`RX:extensions/browser-tabs/src/utils/applescript-utils.ts:155-170`). Zen and Firefox tabs come from the session-store file instead (`RX:extensions/zen-browser/src/util/index.ts:139-172`), because Firefox has no dictionary. Switching raises the window (`set index of w to 1`), then sets `active tab index`.
- **Alfred.** Community workflows, for example alfred-browser-tabs, use bulk JXA reads guarded by `running()`. Whether Alfred 5 has built-in tab search is unverified.
- **Contexts.** Handles native `NSWindow` tabs ("lists a separate window for each tab"); no evidence of browser-tab search (https://contexts.co/whats-new/).
- **Witch.** Reaches "any tab in any window (assuming the app has mac-standard tabs that Witch can see)" through the Accessibility API, with Safari as its example (https://manytricks.com/witch/help). No documented Chrome mechanism.
- **AltTab.** Handles native tabs only ("Show *standard* tabs as windows"). #5155 (browser tabs) was closed as "Not possible technically, alas". #2957 explains that browsers draw custom tabs that can't be listed as windows or screenshotted, and #2771 (tab groups) was declined for the same reason. That refusal is about treating tabs as *windows with thumbnails*, which AltTab's model requires. It doesn't rule out reading tab titles and URLs over AppleScript, which AltTab chose not to do.
- **Hammerspoon.** `hs.tabs` fakes tabs from windows. The real AX tab code is `hs.window:tabCount`/`focusTab` (§3).
- **DockDoor.** No tab listing (feature request #925 open).
- **TabTab** (tabtabapp.net). Claims AX-only tab listing across Chrome, Safari, VS Code, Xcode, Finder, and others. That's vendor copy. If true, it relies on Chromium's lighter AX mode exposing the tab strip, and it still wouldn't get URLs for background tabs.

## 8. Per-family table

| Family | Mechanism | Permission | Cost per read | Freshness | Exposes |
|---|---|---|---|---|---|
| Chrome, Brave, Edge, Vivaldi, Opera, Comet, Helium | AppleScript bulk read `{id, name, bounds, active tab index}` of windows plus `{id, title, URL}` of tabs of windows; switch via `active tab index` | Automation per browser | ~100–500 ms per app (extrapolated, unmeasured) | Poll: on Picker open, deactivate, title change | `w.tabs[].title`, `.url`, `.active`, `.index`; `w.incognito` |
| Arc, Dia | Own AppleScript dialect; switch via `select` / `focus` | Automation per browser | similar | same | as above; Arc adds space and pinned |
| Chromium via AX | `AXTabGroup` → `AXTabButton` titles | Accessibility | up to 250 ms per window | event-assisted | titles and active index only; fallback when Automation is denied |
| Chromium via CDP | `chrome://inspect` toggle | none, but a Chrome dialog per connection | low | push possible | rejected |
| VS Code, Cursor, Antigravity | Tier 1: window title template plus `AXDocument`. Tier 2: small extension writing `tabGroups` to a file or socket | Tier 1: Accessibility. Tier 2: none | Tier 1: ~1 ms per window. Tier 2: file read | Tier 1: WinMux title cache. Tier 2: pushed on change | Tier 1: `w.document`, folder from title. Tier 2: `w.tabs[].title`, `.path`, `.active`, `w.folders` |
| Obsidian | `workspace.json` plus title | none (unless vault is TCC-protected) | <1 ms | FSEvents | `w.tabs[].title`, `.path`, `.active` |
| Native `NSWindow` tabs (Finder, Terminal, TextEdit, Ghostty, Safari when it uses them) | Already WinMux windows; group by `AXTabGroup` token and same-frame siblings | Accessibility | up to 250 ms per window, backstop only | event-driven (create, destroy, focus) | `w.tabs` = sibling windows; `w.tabGroup`; each tab is its own Picker entry |
| Ghostty, cmux | AppleScript (`select tab`) as well as §3 | Automation | small (unmeasured) | poll | `w.tabs[].title`, `.path` (= cwd), `.active` |
| iTerm2 | AppleScript (deprecated but present) | Automation | small (unmeasured) | poll | `w.tabs[].title`, `.active`; tty |
| Safari | AppleScript (`current tab`) or `AXTabs` | Automation, or Accessibility for titles only | small (unmeasured) | poll | `w.tabs[].title`, `.url`, `.active` |
| Xcode | Title, `AXDocument`, sdef `workspace document.path` | Accessibility (Automation for sdef) | ~1 ms | title cache | `w.document`, workspace path |
| Zed | Title, `AXDocument` if set | Accessibility | ~1 ms | title cache | `w.document` at most |

## 9. Recommendation

1. **Expose tabs as a cached attribute, never a live read.** Proposed CEL shape:
   - `w.tabs: list<Tab>`, where `Tab = {title: string, url: string, path: string, active: bool, index: int}`. Use `""` for an absent `url` or `path`, so comprehensions like `w.tabs.exists(t, t.url.contains("github.com"))` need no optional guards.
   - `w.tabsSource: string`, one of `"applescript"`, `"native"`, `"extension"`, `"file"`, `"ax"`, `""`.
   - `w.tabsAge: duration`, so a binding can ignore stale data if it wants.
   - `w.document: string`, the `AXDocument` path, cheap.
   - `w.incognito: bool`.
   - Everything under `w.tabs` comes from memory. Every Picker open reads the cache and then schedules a refresh, and the cache fills off the main thread per app.
   - That matches research 03's lazy-context point: an expensive fact is never computed for a binding that doesn't use it. Check the parsed CEL for references to `w.tabs`, and treat type-to-search over tab titles as a reference too.
2. **Build order**, by value to Prateek per unit of effort. §10 revises this: build the provider interface first and implement (b)–(f) as providers.
   - a. `w.document` plus title (free).
   - b. Chrome-dialect AppleScript for Chrome and its derivatives, with the one-time Automation grant flow and the title-plus-bounds mapping.
   - c. Native-tab grouping. It's needed anyway to fix the blank-tile inheritance from AeroSpace #68.
   - d. Ghostty, Safari, and iTerm2 dictionaries, which are small once (b) exists.
   - e. A VS Code-family extension, only if title plus `AXDocument` proves too thin.
   - f. Arc and Dia dialects, only if Prateek actually uses them.
3. **Switching:**
   - Focus the WinMux window first, through the existing `nativeFocus` path, so workspace and MRU bookkeeping stay WinMux's. Then send the tab switch (`active tab index`, `current tab`, `select tab`, `select`/`focus`).
   - For native tabs, focusing the tab's own window is the switch.
   - For VS Code, the extension would need a command channel back, which is one more reason to defer it.
4. **Don't** set `AXEnhancedUserInterface` or `AXManualAccessibility`, and don't use CDP.
5. **Picker-entry question** (for the "Tab-aware Pickers" fog item):
   - Native tabs are *already* separate entries. For them the choice is grouping (collapse to one entry per tab group, or not), which fits research 03's grouping modes (`window`, `app`, `workspace`, `tab group`).
   - For scripted tabs, start with `w.tabs` as a searchable attribute. A query that matches a tab rather than the window title shows that tab under the window's entry, and choosing it focuses and switches. Promote scripted tabs to their own entries only if that proves wanted.

## 10. Sidebar-driven apps, and a provider registry instead of per-app code

Added 2026-09-29 at Prateek's request. The question: should WinMux also cover apps whose "tabs" live in a sidebar, such as Orca, or should apps plug in through a registered provider?

### Sidebar apps on this Mac

- **Orca** (`com.stablyai.orca`, Electron). The sidebar holds worktrees, and each worktree holds terminal tabs (and browser panes). There's no scripting dictionary, and the AX route has the same problems as VS Code's. Orca ships a CLI (`orca`) that talks to its local runtime with no TCC permission:
  - `orca terminal list --json` returns one row per terminal. Each row has `handle`, `worktreeId`, `worktreePath`, `branch`, `tabId`, `title`, `lastOutputAt` and `agentIdentity`. Three runs over 9 terminals took 0.08–0.10 s wall time each, including process spawn. That's the only latency I measured in this whole ticket.
  - `orca worktree list --json` adds `displayName`, `isPinned`, `isUnread`, `lastActivityAt` and `workspaceStatus`.
  - `orca terminal switch --terminal <handle>` brings a tab to the front.
  - `orca status --json` reports the app's pid.
  - Gaps: rows don't say which Orca window they belong to, or which worktree is currently shown. Mapping to a WinMux window is by pid, which is enough while Orca has one window. Whether Orca opens more than one window is unverified.
- **cmux** (`com.cmuxterm.app`, native). Besides its AppleScript dictionary (§4), its CLI talks to a unix socket:
  - `list-windows`, `list-workspaces --window`, `tree --all`, `focus-window`, `focus-pane` and `identify` cover listing and switching.
  - `cmux events` streams newline-delimited JSON events, with `--snapshot`, `--after <seq>` and `--reconnect`. That's the push model: WinMux could hold one long-lived subscription instead of polling.
  - The socket may need a password (`--password`, `CMUX_SOCKET_PASSWORD`, or the one saved in cmux's settings).
- **Arc and Dia** are the browser version of a sidebar app and are covered in §1. Superset (Electron, installed) has no CLI on `PATH`. I didn't look further.

The pattern: sidebar apps built for agents increasingly ship a JSON CLI or socket. That beats both AppleScript (no Automation grant) and AX (no side effects). Neither can be scraped generically, though, so each needs an adapter.

### Proposal: tab providers

Keep WinMux's core out of per-app knowledge. A **tab provider** is anything that answers "what are the tabs of this app's windows, and how do I switch to one". Register providers in config, and make the built-in routes (Chrome AppleScript, native tabs, Ghostty) providers too, so there's one code path.

**Registration.** Match on bundle id. Offer two modes, following Alfred's Script Filter (pull, JSON on stdout, with a `cache` and `rerun` hint; https://www.alfredapp.com/help/workflows/inputs/script-filter/json/) and cmux's event stream (push):

```toml
[[tab-provider]]
app-id = "com.stablyai.orca"
list = ["orca", "terminal", "list", "--json"]          # pull: run on Picker open, with a timeout
transform = "~/.config/winmux/providers/orca.jq"        # optional: map the app's JSON to WinMux's schema
activate = ["orca", "terminal", "switch", "--terminal", "{tab.id}"]
timeout-ms = 300

[[tab-provider]]
app-id = "com.cmuxterm.app"
watch = ["cmux", "events", "--reconnect"]               # push: long-lived, each line triggers a re-list
list = ["cmux", "tree", "--all", "--json"]
activate = ["cmux", "focus-pane", "--pane", "{tab.id}"]
```

`cmux tree --all --json` exists (per its `--help`). The exact `activate` target for cmux is illustrative.

Apps or extensions that want to push directly (a VS Code extension, an Orca plugin, or Orca itself) can use a WinMux CLI verb instead: `winmux tabs publish --app-id <id> --pid <pid> < tabs.json`. The fork's "everything is scriptable" note on the map already calls for a verb like this.

**Schema** (one version-tagged JSON document per app):

```json
{ "version": 1,
  "windows": [
    { "match": { "windowId": 1324, "pid": 57173, "title": "…", "bounds": [0, 0, 1720, 1410] },
      "tabs": [
        { "id": "term_abc", "title": "claude", "url": "", "path": "/…/worktree",
          "group": "wayfind-fork", "active": true, "meta": { "branch": "prateek/wayfind-fork" } } ] } ] }
```

- **`match`**: the provider supplies whatever it knows, and WinMux matches in order: `windowId` (exact), then pid plus title, then pid plus bounds, then pid alone if the app has one window.
  - Electron providers that run in the main process can supply the exact `CGWindowID`. Electron's `BrowserWindow.getMediaSourceId()` returns `window:<id>:<other>`, where on macOS `<id>` is the `CGWindowID` (https://www.electronjs.org/docs/latest/api/browser-window). Orca itself could publish that. A VS Code extension can't reach `BrowserWindow`, so it falls back to pid plus title.
- **`group`**: the sidebar level (Orca worktree, cmux workspace, Arc space, VS Code editor group). This gives sidebar apps a two-level structure without a second attribute.
- **`meta`**: `map<string, string>`, opaque to WinMux and readable from CEL (`t.meta.branch == "main"`).

**CEL.** The `Tab` type from §9 grows `id: string`, `group: string` and `meta: map<string, string>`. `w.tabsSource` becomes the provider's name.

**Runtime rules**, which carry over from §6:
- Run pull providers off the main thread with a hard timeout, at most one in flight per app, and only when a binding uses `w.tabs`.
- Keep the last good answer on failure or timeout, and don't retry a failing provider more than once per Picker open.
- Watch providers are restarted with backoff if they exit.
- Run `activate` after WinMux has focused the window (§9 item 3).
- Built-in AppleScript providers run in-process. User providers that shell out to `osascript` get their Automation grant attributed to WinMux as the responsible process (unverified; see the probes).

**What this changes in the build order (§9 item 2).** Build the provider interface and schema first, with `winmux tabs publish` and the pull runner. Then the Chrome-dialect AppleScript and native-tab providers become the first two built-in implementations. Orca and cmux become config entries plus a `jq` transform, not WinMux code. The VS Code extension becomes a thin publisher. The risk is under-designing the schema for apps nobody has tried yet, so check it against Orca, cmux and Chrome before freezing `version: 1`.

## Unverified claims, with probes for Prateek

Each probe is read-only unless marked. The AppleScript probes will trigger an Automation prompt for Terminal (or whatever app runs them) the first time. That's Prateek's call.

1. **WinMux registers background native tabs as windows** (AeroSpace #68 inheritance). Open Finder and press cmd+T twice. Then run `winmux list-windows --all --format '%{window-id} | %{app-name} | %{window-title}'`. Three Finder rows means yes. Also look for blank tiles.
2. **Chrome AppleScript `name` equals the AX window title**, and the bounds line up with WinMux's frame. Run `osascript -e 'tell application "Google Chrome" to get {id, name, bounds} of every window'` and compare with `winmux list-windows --all --format '%{window-id} | %{window-title}'` filtered to Chrome. Automation prompt.
3. **Bulk-read latency with many tabs.** Run `time osascript -e 'tell application "Google Chrome" to get {title, URL} of tabs of every window'` with Prateek's normal tab load, then repeat against Brave, Edge, and so on if installed. Automation prompt.
4. **Cocoa-scripting window `id` equals `CGWindowID`.** Run `osascript -e 'tell application "Terminal" to get id of every window'` and compare with `winmux list-windows --all --format '%{window-id} | %{app-name}'`. Do the same for Safari. Automation prompt.
5. **VS Code exposes the active file as `AXDocument`.** Open Xcode → Open Developer Tool → Accessibility Inspector, point at a VS Code window, and check its `AXDocument`. Repeat for Zed, Cursor, and Antigravity. This is read-only, though it is an AX client read.
6. **Chrome's tab strip is visible to AX without enhanced mode.** In Accessibility Inspector, point at a Chrome tab. Expect `AXRadioButton`/`AXTabButton` inside an `AXTabGroup`. Don't toggle any settings in the Inspector.
7. **Derivative dictionaries**, readable from disk with no launch: run `/usr/libexec/PlistBuddy -c 'Print OSAScriptingDefinition' '/Applications/<Browser>.app/Contents/Info.plist'`, then `grep -c 'active tab index' '/Applications/<Browser>.app/Contents/Resources/<file>.sdef'` for Brave, Edge, Vivaldi, Arc, Dia, and Thorium, whichever Prateek installs. Only Chrome is installed now.
8. **Chrome tab `id` changes when a tab moves between windows** (one Raycast contributor's report). Probe 2 before and after dragging a tab to another window, reading `id of tabs of every window`. Automation prompt.
9. **Automation grants survive a dogfood release upgrade** under the stable self-signed identity. After granting, upgrade through the tap and check System Settings → Privacy & Security → Automation → WinMux.
10. **Obsidian pop-out windows appear in `workspace.json`.** Open a pop-out, then run `python3 -c 'import json; print(json.load(open("<vault>/.obsidian/workspace.json")).keys())'` and look for a `floating` key.
11. **Cursor and Antigravity honour VS Code's `window.title` variables.** Set the template in each and look at the title bar.
12. **Chrome 146 moved the default inspect port** (a user report). This is irrelevant if CDP stays rejected.
13. **Alfred 5 built-in tab search, and TabTab's AX-only claim.** Not checked. They only matter as prior art.
14. **Orca uses one window** (so mapping by pid alone is enough). Open a second Orca window if the UI allows it, then check `winmux list-windows --all --format '%{window-id} | %{app-name}'`.
15. **Resolved during research:** `cmux tree --help` lists `--json`.
16. **Automation for `osascript` spawned by WinMux is attributed to WinMux.** After WinMux runs a provider that shells out to `osascript`, check which app appears under System Settings → Privacy & Security → Automation.
