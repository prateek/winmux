# Research 03: live thumbnails for parked windows, and AltTab's implementation

Ticket: [03-research-thumbnails-and-alttab](../issues/03-research-thumbnails-and-alttab.md)
Date: 2026-09-28

## Sources and how they were read

- **Apple**: the macOS 26.5 SDK headers at `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk` (cited as `SDK:<framework>/<header>:<line>`). The headers are Apple's own API contract. The fetch gateway was down this session, so I did not read developer.apple.com prose. Anything the headers don't say, I flag.
- **AltTab**: `https://github.com/lwouis/alt-tab-macos` at commit `0d9d710` (2026-09-26), cloned to `/tmp/alt-tab-macos` (cited as `AT:<path>:<line>`). It's GPL-3, so I read it for design only and quote no code. AltTab keeps design notes in `*Specs.md` files next to the code. Those notes include measurements the authors took themselves; I cite them as AltTab's measurements, not mine.
- **WinMux**: this repo at `470eedbf` (cited as `WM:<path>:<line>`).
- **Not done**: I took no capture measurements of my own. Every latency number below comes from AltTab's specs, on hardware and window mixes that aren't Prateek's.

## 1. Can we capture parked, minimized, and hidden windows?

### How WinMux hides windows

- An inactive workspace's windows are moved with AX so that the window's top-left sits 1 px inside the monitor's bottom-left or bottom-right visible corner, with the rest of the window off-screen (`WM:Sources/AppBundle/tree/MacWindow.swift:163-198`). The corner choice is in `WM:Sources/AppBundle/layout/refresh.swift:398-423`.
- Inactive tabs in a tab group are parked the same way (`WM:Sources/AppBundle/layout/layoutRecursive.swift:260-268`), so Columns whose Overflow policy is "tab group" produce more parked windows.
- WinMux does not use macOS Spaces for workspaces. Parked windows stay ordered in on the current Space. Native-minimized, native-fullscreen, and hidden-app windows live in their own containers (`WM:Sources/AppBundle/tree/MacWindow.swift:222-223`, `WM:Sources/AppBundle/normalizeLayoutReason.swift:58-76`).

### What the capture APIs can reach

| Window state | ScreenCaptureKit one-shot | `CGWindowListCreateImage` |
|---|---|---|
| Parked (partially off-screen, ordered in) | Works. AltTab reports that `captureScreenshot` succeeds for "partially-offscreen" windows (`AT:src/events/WindowCaptureEventsSpecs.md:18-21`). The filter captures "just the independent window passed in" (`SDK:ScreenCaptureKit/SCStream.h:142-146`). | Works in principle (window is on-screen). WinMux already calls it for tab previews (`WM:Sources/AppBundle/ui/tabs/DoubleSidedWindowController.swift:35-38`). |
| Native-minimized | Works per AltTab (`AT:src/events/WindowCaptureEventsSpecs.md:20`). It gets the last frame before minimize. | Does not work, per AltTab's comment (`AT:src/events/WindowCaptureEvents.swift:290`). |
| Hidden app (cmd+H), or any ordered-out window | Doesn't work. AltTab says an ordered-out window "can't be screenshotted" and the capture comes back as a blank "skeleton", so it keeps the last on-screen frame (`AT:src/switcher/state/WindowEventReducer.swift:1229-1231`, `AT:src/switcher/state/WindowThumbnails.swift:27-29`). | Same. |
| Native fullscreen on an inactive Space | `captureScreenshot` fails with SCStreamError -3811. `captureSampleBuffer` works (`AT:src/events/WindowCaptureEventsSpecs.md:19-26`). | n/a |

The APIs involved:

- `SCScreenshotManager.captureScreenshot(contentFilter:configuration:)` with `SCScreenshotConfiguration` is macOS 26+ (`SDK:ScreenCaptureKit/SCScreenshotManager.h:44,169`). `captureImage` and `captureSampleBuffer` are macOS 14+ (`:143,152`).
- `SCContentFilter(desktopIndependentWindow:)` takes an `SCWindow`, not a `CGWindowID` (`SDK:ScreenCaptureKit/SCStream.h:146`). You get `SCWindow`s from `SCShareableContent.getExcludingDesktopWindows(_:onScreenWindowsOnly:)`. Pass `onScreenWindowsOnly: false` to include off-screen and minimized windows (`SDK:ScreenCaptureKit/SCShareableContent.h:156-162`). AltTab calls this enumeration "expensive for the OS", caches the `SCWindow` list, and re-queries only for window IDs it hasn't seen (`AT:src/events/WindowCaptureEvents.swift:6-9,165-180`).
- `CGWindowListCreateImage` is marked deprecated in 14.0 and obsoleted in 15.0 with "Please use ScreenCaptureKit instead" (`SDK:CoreGraphics/CGWindow.h:223-224,271-274`). WinMux still compiles against it only because its deployment target is macOS 13 (`WM:Package.swift:10`). It's also synchronous, and today it's called on the main thread.

### Caveat: are parked thumbnails live, or just last-painted?

The window server can hand back a parked window's backing store. Whether the app keeps repainting that store while parked is a separate question:

- AppKit counts a window as visible if "at least part of the window is visible" (`SDK:AppKit/NSWindow.h:186`). A parked window keeps 1 px on-screen at a monitor corner. If a tiled window on the visible workspace or the Dock covers that pixel, the parked window is fully occluded. Apps that throttle painting when occluded would then stop updating, so the capture shows whatever was last painted.
- I found no source that settles how Chrome, Electron, or Safari behave here. Expect a parked window's thumbnail to be accurate as of roughly when it was parked, and possibly fresher. A 10-minute prototype would settle it: park a terminal running `watch date`, capture it, and compare.

## 2. Cost and latency for about 50 windows

These are AltTab's numbers from `AT:src/events/WindowCaptureEventsSpecs.md`. Nothing here was measured on Prateek's machine.

- **Throughput is capped by the OS, not the caller.** "The OS serves screenshot requests one at a time." A summon over 43 windows finished in 1.7 s with any in-flight cap from 2 to 16 (2.1 s with a cap of 1) on macOS 27 (`:43-45`). That's roughly 40 ms per window serialized, so **a full refresh of 50 windows takes about 2 s**.
- **Per-request latency under a burst is high.** Mean capture latency was about 644 ms at thumbnail sizes over 29-window bursts (`:67-76`). That number includes queueing.
- **Capture costs CPU outside our process.** Each capture flips replayd's screen-capture attribution. Over about 355 captures, replayd used about 1.8 s of CPU and systemstatusd about 4.7 s (`:63-65,74-75`).
- **`captureSampleBuffer` churns streams.** Each call creates and tears down a capture stream. On some macOS 26 machines that leaked WindowServer memory until forced logout (AltTab issue #5786). `captureScreenshot` creates no per-call stream (`:14-23`).
- **Unbounded bursts wedged capture machine-wide.** Firing 60 simultaneous async requests wedged replayd (AltTab #5861). AltTab now gates captures to 2 in flight and caps queues at 256 (`:40-47`, `AT:src/events/WindowCaptureEvents.swift:188-194`).
- **Before macOS 26, AltTab avoids ScreenCaptureKit.** macOS 14 crashed inside Apple's teardown code and macOS 15 had other bugs, so older systems use the private `CGSHWCaptureWindowList` (`AT:src/switcher/state/WindowThumbnails.swift:171-179`). For this fork that matters only if it ever has to run below macOS 26.

**Conclusion:** capturing all 50 windows at Picker open cannot finish before the first frame. Thumbnails have to come from a cache and refresh in the background, which is exactly what AltTab does.

## 3. How AltTab does it

### Enumerating windows across Spaces and screens

- WindowServer (SkyLight/CGS) events and batched queries supply the physical facts: existence, geometry, Space, minimized, fullscreen. One app-level AX observer per process supplies focus and title (`AT:src/windowserver/README.md:8-22`).
- Other-Space windows are the hard part. There's no API that maps a window ID to an `AXUIElement`, so AltTab brute-forces AX remote tokens on a 250 ms budget and caches the elements it finds (`AT:src/windowserver/README.md:34-46`).
- **Relevance to WinMux: low.** WinMux keeps every managed window on the current Space with an AX element already in its tree (`WM:Sources/AppBundle/ui/hud/SwitcherPalette.swift:159-162` enumerates `Workspace.all`). The only other-Space windows are native-fullscreen ones. Don't port this machinery.

### Capture and cache pipeline

- **The cache lives on the window model.** `Window.thumbnail` holds the last good capture, either an IOSurface or a CGImage (`AT:src/switcher/state/Window.swift:40`). It persists between switcher sessions.
- **Captures are thumbnail-sized.** Pixel size is clamped to the largest tile size the panel can show (`AT:src/switcher/state/WindowThumbnails.swift:45-56`). Full-resolution frames are fetched just in time, only for the selected window and its ±2 neighbours, into a per-session cache that is dropped at dismiss (`:181-198`).
- **Background capture is on by default.** `captureWindowsInBackground` defaults to true (`AT:src/preferences/Preferences.swift:45`). External window events trigger re-captures while the switcher is closed. The just-focused window is also captured, at most once per 800 ms, so it has a fresh frame before it gets backgrounded (`AT:src/switcher/state/WindowThumbnails.swift:23-37`).
- **Captures run off-main.** Window size and scale are snapshotted on main, then the work goes to a background queue behind the 2-in-flight gate (`AT:src/events/WindowCaptureEvents.swift:40-65,188-213`).
- **Bad frames are refused.** A capture much smaller than expected, such as one taken mid un-minimize animation, is dropped and retried up to 3 times (`AT:src/switcher/state/WindowThumbnails.swift:95-150`). Captures are also skipped for 0.7 s after an un-minimize (`:66-92`).

### Keeping opening fast

- **Show first, capture after.** The panel is built from cached thumbnails and shown. Only then is a refresh of every window enqueued, with the tiles in the viewport first (`AT:src/App.swift:415-440`).
- **Display delay.** The default `windowDisplayDelay` is 100 ms, so a quick tap-and-release switch never draws the panel (`AT:src/preferences/Preferences.swift:25`, `AT:src/App.swift:395-409`).
- **Pre-built panel and tile pool.** The panel is a pre-built, non-activating `NSPanel` (`AT:src/switcher/main-window/TilesPanel.swift:17`). Tiles come from a pool that grows and never shrinks (`AT:src/switcher/main-window/TilePoolSpecs.md:5-25`).
- **Stale captures are dropped.** Work queued for a session that has since ended is discarded before it reaches the OS (`AT:src/events/WindowCaptureEvents.swift:57,195-198`).

### MRU ordering

- **Single writer.** One attention model owns the order. Only a confirmed attention decision (a click naming a window, or the app reporting its focused window) or a structural repair may write `focusedAt` (`AT:src/window-tracking/AttentionOrderSpecs.md:1-50`).
- **Choosing a tile doesn't bump MRU.** AltTab's own selection asks the OS to focus the window, and the order moves only when the OS confirms. That avoids MRU claiming a window the user never reached (`:32-43`).
- **Sort options.** Sort types are `recentlyFocused`, `recentlyCreated`, `alphabetical`, and `space`. Search rank comes first when a query is active. Hidden, minimized, and windowless buckets can sink to the end (`AT:src/switcher/state/WindowOrderResolverSpecs.md:15-25`).

## 4. WinMux's `SwitcherPalette` today

- **Panel.** A singleton `NSPanelHud` (`nonactivatingPanel` plus `borderless`, `WM:Sources/AppBundle/ui/hud/NSPanelHud.swift:3-11`) hosting SwiftUI through `NSHostingView`. It sits at a fixed 560×440, a quarter of the way down the focused monitor (`WM:Sources/AppBundle/ui/hud/SwitcherPalette.swift:5-7,48-100`).
- **Rows.** Icon, title, and a ⌘1-9 badge for quick-select. Fuzzy search runs over app name, title, and workspace. Esc, arrow, and Return are intercepted in `sendEvent` (`:124-143,205-240,306-349`).
- **Items are rebuilt on every show.** Titles are fetched concurrently, and the build awaits them, so opening can suspend on AX title reads (`:155-201`). The order is focused workspace first, then `Workspace.all`. **It is not MRU.**
- **Activation.** Showing it calls `NSApp.activate` and `makeKey` (`:97-99`). That suits type-to-search but is wrong for a hold-to-cycle strip, which should not steal activation.
- **Selection.** Selecting calls `markAsMostRecentChild`, `setFocus`, and `nativeFocus` (`:109-120`). There is no Summon path yet.
- **Entry point.** It is opened by the `palette` command (`WM:Sources/AppBundle/command/impl/PaletteCommand.swift:8-11`).
- **No global MRU.** WinMux keeps a per-parent MRU stack (`WM:Sources/AppBundle/tree/TreeNode.swift:112-115`) and `prevFocus` / `prevPrevFocus` (`WM:Sources/AppBundle/focus.swift:60-65`). There is no cross-workspace MRU list, so the strip's MRU default needs a new per-window focus timestamp.
- **Building blocks already present:**
  - A global and local `flagsChanged` monitor, usable for modifier-release detection (`WM:Sources/AppBundle/GlobalObserver.swift:159-160`).
  - Screen-capture permission plumbing (`WM:Sources/AppBundle/util/accessibility.swift:15-16`, `WM:Sources/AppBundle/command/impl/DoctorCommand.swift:14`).
  - A dev-only ScreenCaptureKit capture tool (`WM:Sources/WindowCapture/main.swift:68-108`). It uses `onScreenWindowsOnly: true`, which would miss minimized windows, and `captureImage`.

## 5. Recommendation: thumbnail strategy

1. **Use ScreenCaptureKit one-shot captures only, and require macOS 26 for thumbnails.**
   - Use `captureScreenshot` for everything except native-fullscreen windows. Those use `captureSampleBuffer`, or fall back to a cached thumbnail or the app icon.
   - Below macOS 26, show icons. Don't use the private `CGSHWCaptureWindowList`. Everything WinMux has to reach (parked, minimized) is covered on 26. This assumes Prateek's daily machine runs macOS 26+; this machine reports Darwin 25.5, which is macOS 26.5.
2. **Keep a thumbnail cache on WinMux's `Window` model.** Store a thumbnail-sized CGImage keyed by window ID and invalidate it on close.
   - Capture a window **as it gets parked** (workspace switch, or tab deactivation in `hideInCorner`) and **on focus-out**, throttled per window. That gives an accurate "last seen" frame even for apps that stop painting once occluded, and it's the moment WinMux already knows about.
   - Also re-capture on title and resize events, throttled.
3. **Picker open never waits on capture.**
   - Render from the cache immediately; windows with no capture yet show the app icon.
   - Then refresh the visible tiles first behind a 2-in-flight gate, and drop the queued work when the Picker closes.
   - Cache `SCWindow`s from one `SCShareableContent(onScreenWindowsOnly: false)` call, and re-enumerate only when a window ID is missing.
4. **Hidden-app windows keep their last cached frame, or show the icon.** They are ordered out and cannot be captured. WinMux's `automaticallyUnhideMacosHiddenApps` (`WM:Sources/AppBundle/normalizeLayoutReason.swift:59`) makes this rarer anyway.
5. **Size captures to the tile.** Use the grid's largest tile size times the backing scale. Fetch full resolution only if a Preview-style enlargement is added later.
6. **Don't use per-window `SCStream`s for "truly live" tiles.** I found no source measuring 50 concurrent streams, and AltTab deliberately avoids stream churn. If live video of the selected tile turns out to be wanted, prototype a single stream for the selection only.

## 6. AltTab design choices worth adopting, mapped to the Picker model

| AltTab choice | Maps to | Adopt? |
|---|---|---|
| Per-shortcut filter knobs: `appsToShow` (all, active, non-active), `spacesToShow`, `screensToShow`, show/hide/at-end for minimized, hidden, and fullscreen (`AT:src/preferences/Preferences.swift:54-66`) | Filter plus per-binding sort | Yes, as the **built-in Filter vocabulary**. Each knob is a predicate over the Filter context. "Show at the end" is a sort key, not a filter, which argues for keeping sort separate from Filter in the Picker binding. |
| Filter is a pure predicate with the expensive fact lazily evaluated and short-circuited (`AT:src/switcher/state/WindowFilterResolverSpecs.md:5-16`) | Filter runtime | Yes. That's the shape to aim for with JS predicates: pass a lazy context so an unused expensive fact (window under mouse, on-screen test) is never computed. |
| Sort types plus "search rank first when typing" (`AT:src/switcher/state/WindowOrderResolverSpecs.md:15-25`) | Picker binding sort | Yes. Offer MRU, created, alphabetical, and workspace. |
| One-window-per-app vs all windows (`showAppsOrWindows`), and tabs as one or many (`AT:src/preferences/MacroPreferences.swift:230-253`) | Picker binding grouping | Yes, as grouping modes (`window`, `app`, `workspace`). Add `tab group` to match WinMux's own tab groups. |
| Release styles `focusOnRelease`, `doNothingOnRelease` ("Hold"), `searchOnRelease` (`AT:src/preferences/MacroPreferences.swift:110-118`) | Strip Presentation keyboard model | Yes. It answers part of the "Strip visuals and keyboard model" fog. Treat release behaviour as a per-binding option. |
| 100 ms display delay before drawing (`AT:src/preferences/Preferences.swift:25`) | Strip Presentation | Yes, for the strip. A quick tap then flips to the previous window with no flash. |
| Show panel from cache, then refresh the viewport first (`AT:src/App.swift:415-440`) | Grid and strip | Yes (§5). |
| Selecting doesn't bump MRU; only a confirmed focus does (`AT:src/window-tracking/AttentionOrderSpecs.md:32-43`) | Global MRU for the strip default | Yes, simplified: WinMux gets focus confirmations from its own refresh loop, so write the timestamp there, not in the Picker's `select`. |
| Non-activating panel (`AT:src/switcher/main-window/TilesPanel.swift:17`) | Strip Presentation | Yes. The strip must not call `NSApp.activate` the way `SwitcherPalette` does today. The grid with type-to-search may still need key status. |
| Keyboard state machine that survives dropped and out-of-order key events (`AT:src/events/KeyboardEventsSpecs.md:5-20`) | Trigger handling for hold-to-cycle | Yes, in spirit: build release detection as a testable state machine fed by WinMux's existing `flagsChanged` monitor. |
| Cross-Space AX brute-force, SkyLight event tap, attention engine | – | No. WinMux doesn't use Spaces and already tracks windows. |

## Open questions surfaced

- **Parked-window freshness**: do Chrome, Electron, and Safari keep painting a parked window whose one on-screen pixel is covered? This decides whether capture-on-park is enough or whether periodic background refresh is needed. Needs a short prototype.
- **Real latency on Prateek's machine**: time ScreenCaptureKit `captureScreenshot` over his actual ~50 windows, both cold (first `SCShareableContent`) and warm. AltTab's numbers come from 29–43 windows on other hardware.
- **Deployment target**: raise WinMux's minimum to macOS 26, or gate thumbnails with `#available`? The latter is cheap; raising the target would also retire the three `CGWindowListCreateImage` call sites.
- **Global MRU**: where to write a per-window focus timestamp in WinMux's refresh loop, and how it relates to per-parent `_mruChildren`.
- **Screen-capture indicator**: whether frequent background captures show the menu-bar recording indicator or privacy UI on macOS 26. AltTab mentions the replayd attribution cost but not user-visible UI (`AT:src/events/WindowCaptureEventsSpecs.md:63-65`). Unverified.
