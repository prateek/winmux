# Thumbnail cache and the `'miniatures` Presentation

Part of {{UMBRELLA}}.

## What to build

Give every window a thumbnail that is captured in the background and kept on the window, so that a Lens can draw thumbnails the moment it opens. Then build the `'miniatures` Presentation, which draws each workspace as a small copy of itself with every window where it actually sits, over a dimmed, see-through backdrop. Ship the default `overview` Lens on it.

## Decisions

**Capture**

- Thumbnails come from ScreenCaptureKit's one-shot window capture: `SCScreenshotManager.captureScreenshot(contentFilter:configuration:)`, with a filter built by `SCContentFilter(desktopIndependentWindow:)`. Raise the deployment target to macOS 26 decides the call, and this issue follows it. There is no `#available` gating and no use of `CGWindowListCreateImage` or of private capture APIs.
- Do not use a per-window `SCStream` to keep thumbnails live.
- The one-shot capture reaches parked windows (WinMux parks a window by moving it almost entirely off-screen) and minimized windows. It cannot capture a hidden-app window once the app is hidden, because the window is ordered out and the capture comes back blank.
- A native-fullscreen window on an inactive Space fails with the one-shot call. What such a window shows is under Defaults chosen for you.
- The filter takes an `SCWindow`, not a window id. Get the `SCWindow` list from `SCShareableContent` with `onScreenWindowsOnly: false`, so that off-screen and minimized windows are included. Cache that list and refresh it when windows are created or destroyed. Never request it on the Lens-open path: one request costs about 30 ms. The existing dev tool in `Sources/WindowCapture/main.swift` uses `onScreenWindowsOnly: true` and is not a model for this.
- Captures run off the main thread, with at most 2 in flight. More than 2 gains nothing, because the system serialises them, and unbounded bursts are known to wedge capture machine-wide.
- Measured cost on a stand-in machine: 33 ms per capture one at a time, 113 ms for the first capture after launch, about 21 ms per window with 2 in flight, and about 1 s for 50 windows. Thumbnail-sized and native-sized captures cost the same. These figures were taken with `captureImage`, so they are re-measured with `captureScreenshot` as part of this issue.

**The cache**

- Each `Window` holds one thumbnail-sized image, the last good capture. It is dropped when the window closes.
- Capture at thumbnail size: the largest size a Lens draws an entry at, times the backing scale.
- A window is captured when it is parked (a workspace switch, or a tab in a tab group going inactive; both go through `hideInCorner` in `Sources/AppBundle/tree/MacWindow.swift`) and when it loses focus. Captures are throttled per window.
- A minimized window keeps the frame captured at minimize. A hidden-app window keeps the last frame captured before the hide.
- Capture at park is the capture that matters. Chrome-family browsers, Electron apps and Metal-backed apps stop painting within a second of being fully covered, and a parked window's one visible pixel normally sits under another window. A capture taken later returns the same park-time frame, never a blank. So re-capturing parked windows when a Lens opens only repeats the frame at 33 ms each, and is not done as a general refresh.
- Safari keeps painting while covered, so a later capture of a parked Safari window would be fresh. The first version does not use that; see Defaults chosen for you.
- A window with no capture shows its app icon.

**Opening a Lens never waits on capture**

- A Lens draws from the cache at once.
- After it has drawn, visible entries are refreshed first, behind the 2-in-flight gate.
- Queued captures are dropped when the Lens closes.

**Thumbnail states a Lens shows**

- Windows on the current workspace are live.
- Parked windows show their park-time frame. This is a Frozen thumbnail.
- Minimized and hidden-app windows show the frame captured at minimize or before the hide.
- The Lens field `frozen-thumbnail` says how a Frozen thumbnail is marked. Live thumbnails are never marked.

**The `'miniatures` Presentation**

- It draws each workspace as a small, to-scale copy of itself. Tiled windows sit in their Columns or tree positions and floating windows sit on top, where they are on the real workspace.
- Workspaces are arranged in a grid of cells in sidebar order.
- Minimized and hidden-app windows sit in a tray under their workspace.
- A hidden-app window's workspace is the one its container belongs to (`MacosHiddenAppsWindowsContainer` in `Sources/AppBundle/tree/MacosUnconventionalWindowsContainer.swift`). A minimized window sits in one global container outside every workspace, so its tray is the workspace it was on when it was minimized. Filter contract v1 and `config schema` builds that memory and reports it as `w.workspace`; this issue reads it and does not build it.
- Window titles are hidden. The selected window's title appears under its workspace.
- Sections are always workspaces, entries are always windows, and sort order does nothing. Under `'miniatures` the Lens contract rejects `sections`, `entries` and `sort`.
- When the workspaces do not fit at a readable size, they are shown on pages or shrunk, as `fit` says. Scrolling turns the page.
- Tuning numbers stay out of the config: the readable floor (110 points of workspace height), gaps and badge sizes.
- Known risk: at the 110-point floor a Column on a laptop screen can be about 85 points wide, so two windows of the same app on one workspace look alike until one is selected. The selected window's title, the app icons and Search are the mitigations. Check this on the real build before changing the floor.

**Settings**

- Layout settings live in a `miniatures` record on the Lens. Look settings shared with other Presentations are fields of the Lens itself. Both can be overridden per Display profile through `when.<profile>`; the only profile for now is `"default"`.
- Every field name and enum tag is spelled with hyphens.
- The shipped defaults:

  ```nickel
  lenses.overview = {
    presentation = 'miniatures,
    frozen-thumbnail = 'dimmed,               # 'plain | 'age-badge | 'pause-badge | 'dimmed
    accessory-window = 'enlarged,             # 'enlarged | 'actual-size
    summon-hints = ['label, 'landing-spot],   # any of 'label | 'landing-spot | 'target-workspace
    miniatures = {
      fit = 'page,                            # 'page | 'shrink
      current-workspace = 'highlight,         # 'plain | 'highlight | 'enlarge | 'hide
      arrow-keys = 'nearest,                  # 'nearest | 'by-workspace
    },
  }
  ```

- `fit`: `'page` shows the workspaces on pages; `'shrink` shrinks them to fit.
- `current-workspace`: how the current workspace is marked. `'hide` leaves it out, since it is already visible behind the overlay.
- `arrow-keys`: `'nearest` moves to the nearest window in that direction. `'by-workspace` moves between windows within a workspace with left and right, and between workspaces with up and down.
- `frozen-thumbnail`: how a Frozen thumbnail is marked.
- `accessory-window`: a small window of an Accessory app is drawn with a dashed outline and a "menu-bar app" tag. `'enlarged` grows it to a readable size at its position; `'actual-size` keeps it to scale.
- `summon-hints`: what shows while Summon's modifier is held. `'label` puts "Summon to N" on the selection. `'landing-spot` draws a dashed outline where the window will land. `'target-workspace` outlines the current workspace.
- The contract rejects `current-workspace = 'hide` together with `'landing-spot` in `summon-hints`, because the landing spot is drawn inside the current workspace.

**Selection, keys and Search**

- The Lens's `keys` map applies as in any Lens: `enter` focuses, `shift-enter` runs `summon`. With the mouse, hovering moves the selection, a click runs `enter`'s command and a modifier-click runs the matching modifier binding.
- Arrow keys move the selection as `arrow-keys` says.
- Typing shows a Search box. Non-matching windows dim in place, because positions are fixed. The selection jumps to the best match, and the arrow keys move among matches only.
- `tab` toggles a mark on the selected window, as in any Presentation with a Search box.
- `lens --presentation list` reopens an open `'miniatures` Lens as a list.

**Summon**

- A Summoned window arrives on the current workspace like any tiling window, so the `place` hook picks its Column and Overflow policy action. Summon does not run `arrive`, because the window is not new.
- The landing spot is `place`'s answer. It is computed only while Summon's modifier is held, and once per selection change.

**Backdrop**

- The overlay panel is non-opaque. An opaque full-screen panel would cover every visible window, and they would all stop painting within a second of the Lens opening.
- The backdrop defaults to 60% black with a behind-window blur.
- The allowed range is 0% to 95% black. The config rejects anything darker.
- 100% black freezes the windows underneath even when the panel has `isOpaque = false`: the window server goes by the pixels' actual alpha, not the flag.
- Do not rely on the blur to make a darker backdrop safe. A 100% black layer over one blur material stayed live in testing, and that is not enough to build on.

**The default `overview` Lens**

- `overview` is defined in the shipped `defaults.ncl`, which a user's config imports and merges over. This issue adds it there.
- `overview` matches every window and uses `'miniatures` with the defaults above.
- It does not set `popups`, the Lens field that lists the popup Window classes a Lens includes. It is empty by default, so "every window" leaves out `'accessory-popup` and `'app-popup` windows: they never reach the Filter.
- This issue adds no key binding for it. Default config, Triggers, the `lens` leader mode, `subscribe` events adds the binding.

## Not in this issue

- The `lens` command, the Lens record and contract (including the `popups` field), `keys` actions, `summon`, marks, Search matching and ranking, and the `'list` Presentation: Lens core and the `'list` Presentation with Search.
- Raising the deployment target, choosing the capture call and removing the existing `CGWindowListCreateImage` call sites: Raise the deployment target to macOS 26.
- Remembering the workspace a minimized window was on, and reporting it as `w.workspace`: Filter contract v1 and `config schema`.
- The strip's use of the cache: Strip Presentation and the cmd+tab takeover.
- The `place` hook and Columns: Column Policy hooks and Column commands, and Fixed Columns: slots, the count invariant, Width presets. Until they exist, a miniature draws the tree positions and the landing spot is wherever the built-in insertion would put the window.
- The key that opens `overview` (`o` in the `lens` leader mode): Default config, Triggers, the `lens` leader mode, `subscribe` events.
- Not built in v1: the `'grid` Presentation. A Lens with `presentation = 'grid` is rejected at load as not yet supported.
- Deferred: the three-finger swipe for `overview` and every other trackpad gesture, Display profiles, and tabs. The shipped defaults are the same on every screen.
- Not specified: how the overlay opens (the real windows animating into their places, or a plain fade). This issue requires no animation.

## Depends on

- Raise the deployment target to macOS 26
- Filter contract v1 and `config schema`, for the workspace a minimized window was on when it was minimized
- Lens core and the `'list` Presentation with Search

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **The backdrop setting.** It is a `backdrop` field in the `miniatures` record: `miniatures.backdrop = { darkness = 0.6, blur = true }`. The contract rejects a `darkness` above 0.95. It sits in the `miniatures` record because the strip and the list have no full-screen backdrop.
- **Capturing before a hide.** Nothing runs before a cmd+H, so WinMux takes no capture ahead of the hide. A hidden-app window shows its last capture from when it lost focus or was parked, and the app icon if it has none.
- **Native-fullscreen windows on an inactive Space.** They show their last captured frame, or the app icon if there is none. `captureSampleBuffer` is not used: it creates and tears down a stream per call.
- **Throttle interval.** A park or focus-loss capture of one window runs at most once per 800 ms. Title and resize events do not trigger a capture.
- **Telling a Frozen thumbnail from a fresh one.** Every parked, minimized and hidden-app window's thumbnail counts as Frozen and is marked as `frozen-thumbnail` says. WinMux does not detect apps that keep painting while covered, so a parked Safari window is marked like any other and is not re-captured when a Lens opens.
- **Keeping current-workspace windows live.** While a Lens is open, the visible windows of the current workspace are re-captured every 500 ms, behind the 2-in-flight gate. The 800 ms throttle does not apply to this refresh.
- **The `'age-badge` and `'pause-badge` looks.** `'age-badge` desaturates and slightly darkens the thumbnail (saturation 35%, brightness 85%) and adds a badge with the capture's age. `'pause-badge` leaves the thumbnail as it is and adds a pause glyph in a corner. Both follow the grid prototype.
- **`--presentation miniatures` on a Lens that sets `sections`, `entries` or `sort`.** The override opens the Lens as miniatures and ignores the three fields.
- **Popup-class windows.** They sit outside every workspace and report `w.workspace` as `""`, so `'miniatures` has nowhere to draw them. A `'miniatures` Lens does not draw them even when its `popups` lists a class.

## Done when

- [ ] Switching away from a workspace captures its windows; opening a Lens afterwards shows their thumbnails with no visible delay.
- [ ] A window that has never been captured shows its app icon.
- [ ] No more than 2 captures are in flight at any time, and opening a Lens with 50 windows does not block on capture.
- [ ] Closing a Lens drops its queued captures, and closing a window drops its thumbnail.
- [ ] The capture path calls `SCScreenshotManager.captureScreenshot(contentFilter:configuration:)` and nothing else. The per-capture cost is re-measured with it on a real set of about 50 windows, and the figures are in the pull request.
- [ ] A signed WinMux build with its own Screen Recording grant is checked for a screen-recording indicator during background captures, and the result is in the pull request.
- [ ] `winmux lens overview` opens the `'miniatures` Presentation: every workspace drawn to scale in sidebar order, tiled windows in their real positions, floating windows on top, minimized and hidden-app windows in a tray under their workspace. No popup-class window is drawn.
- [ ] A window minimized on one workspace, with another workspace focused afterwards, appears in the tray of the workspace it was minimized on.
- [ ] A hidden-app window and a native-fullscreen window on an inactive Space each show their last capture, or the app icon when they have none.
- [ ] The current workspace is highlighted, Frozen thumbnails are dimmed, and a small Accessory app window is enlarged with a dashed outline and a "menu-bar app" tag.
- [ ] With a clock running in a window on the current workspace, its miniature advances while the Lens stays open.
- [ ] A Lens with `frozen-thumbnail = 'age-badge` shows the capture's age on parked windows, and one with `'pause-badge` shows a pause glyph.
- [ ] The selected window's title shows under its workspace, and arrow keys move to the nearest window in that direction.
- [ ] `enter` focuses the selected window. `shift-enter` runs `summon`, and while its modifier is held the selection shows "Summon to N" and the landing spot is outlined.
- [ ] Typing dims non-matching windows in place, moves the selection to the best match, and limits the arrow keys to matches.
- [ ] With more workspaces than fit at a readable size, the Lens pages and scrolling turns the page.
- [ ] Windows on the current workspace keep painting behind the overlay while it is open (check with a terminal running a clock, and with an Electron app).
- [ ] A config that sets `miniatures.backdrop.darkness` above 0.95 fails `winmux config check`.
- [ ] A config with `sections`, `entries` or `sort` on a `'miniatures` Lens, or with `current-workspace = 'hide` plus `'landing-spot`, fails `winmux config check`.
- [ ] `winmux list-lenses --json` shows `overview` with the `'miniatures` Presentation and its resolved settings, with every key and enum value spelled with hyphens.
- [ ] `winmux lens <name> --presentation miniatures` opens a configured Lens as miniatures, including one that sets `sections`, `entries` or `sort`, which are ignored.

## Sources

- [Research: live thumbnails for parked windows, and AltTab's implementation](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/03-research-thumbnails-and-alttab.md)
- [Research findings: live thumbnails for parked windows, and AltTab's implementation](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/research/03-thumbnails-and-alttab.md)
- [Task: measure thumbnail capture](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/14-task-measure-thumbnail-capture.md)
- [Task findings: thumbnail capture measurements](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/research/14-thumbnail-capture.md)
- [Thumbnail capture harness](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/prototypes/14-thumbnail-harness)
- [Prototype: grid Presentation look and behaviour](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/08-prototype-grid-presentation.md)
- [Grid Presentation prototype](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/prototypes/08-grid-presentation.html)
- [Prototype: strip Presentation look and keyboard model](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/29-prototype-strip-presentation.md)
- [Task: confirm the grid backdrop keeps Electron and Metal windows live](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/30-task-grid-backdrop-liveness.md)
- [Task findings: grid backdrop liveness for Electron and Metal windows](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/research/30-grid-backdrop-liveness.md)
- [Backdrop liveness harness](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/prototypes/30-backdrop-liveness)
- [Grilling: raise the fork's minimum macOS to 26?](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/15-grilling-deployment-target.md)
- [Grilling: cmd-K search Lens](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/19-grilling-cmd-k-search.md)
- [Grilling: questions left by the review of the build issues](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/35-grilling-build-issue-review.md)
