# Thumbnail cache and the `'miniatures` Presentation

Part of {{UMBRELLA}}.

## What to build

Give every window a thumbnail that is captured in the background and kept on the window, so that a Lens can draw thumbnails the moment it opens. Then build the `'miniatures` Presentation, which draws each workspace as a small copy of itself with every window where it actually sits, over a dimmed, see-through backdrop. Ship the default `overview` Lens on it.

## Decisions

**Capture**

- Thumbnails come from ScreenCaptureKit's one-shot window capture (`SCScreenshotManager` with `SCContentFilter(desktopIndependentWindow:)`). There is no `#available` gating and no use of `CGWindowListCreateImage` or of private capture APIs.
- Do not use a per-window `SCStream` to keep thumbnails live.
- The one-shot capture reaches parked windows (WinMux parks a window by moving it almost entirely off-screen) and minimized windows. It cannot capture a hidden-app window once the app is hidden, because the window is ordered out and the capture comes back blank.
- A native-fullscreen window on an inactive Space fails with the plain one-shot call and needs `captureSampleBuffer`. See Open details.
- The filter takes an `SCWindow`, not a window id. Get the `SCWindow` list from `SCShareableContent` with `onScreenWindowsOnly: false`, so that off-screen and minimized windows are included. Cache that list and refresh it when windows are created or destroyed. Never request it on the Lens-open path: one request costs about 30 ms. The existing dev tool in `Sources/WindowCapture/main.swift` uses `onScreenWindowsOnly: true` and is not a model for this.
- Captures run off the main thread, with at most 2 in flight. More than 2 gains nothing, because the system serialises them, and unbounded bursts are known to wedge capture machine-wide.
- Measured cost on a stand-in machine: 33 ms per capture one at a time, 113 ms for the first capture after launch, about 21 ms per window with 2 in flight, and about 1 s for 50 windows. Thumbnail-sized and native-sized captures cost the same.

**The cache**

- Each `Window` holds one thumbnail-sized image, the last good capture. It is dropped when the window closes.
- Capture at thumbnail size: the largest size a Lens draws an entry at, times the backing scale.
- A window is captured when it is parked (a workspace switch, or a tab in a tab group going inactive; both go through `hideInCorner` in `Sources/AppBundle/tree/MacWindow.swift`) and when it loses focus. Captures are throttled per window.
- A minimized window keeps the frame captured at minimize. A hidden-app window keeps the frame captured before the hide.
- Capture at park is the capture that matters. Chrome-family browsers, Electron apps and Metal-backed apps stop painting within a second of being fully covered, and a parked window's one visible pixel normally sits under another window. A capture taken later returns the same park-time frame, never a blank. So re-capturing parked windows when a Lens opens only repeats the frame at 33 ms each, and is not done as a general refresh.
- Safari keeps painting while covered, so its thumbnails can be refreshed and stay fresh.
- A window with no capture shows its app icon.

**Opening a Lens never waits on capture**

- A Lens draws from the cache at once.
- After it has drawn, visible entries are refreshed first, behind the 2-in-flight gate.
- Queued captures are dropped when the Lens closes.

**Thumbnail states a Lens shows**

- Windows on the current workspace are live.
- Parked windows show their park-time frame. This is a Frozen thumbnail.
- Minimized and hidden-app windows show the frame captured at minimize or before the hide.
- The Lens field `frozen_thumbnail` says how a Frozen thumbnail is marked. Live and fresh thumbnails are never marked.

**The `'miniatures` Presentation**

- It draws each workspace as a small, to-scale copy of itself. Tiled windows sit in their Columns or tree positions and floating windows sit on top, where they are on the real workspace.
- Workspaces are arranged in a grid of cells in sidebar order.
- Minimized and hidden-app windows sit in a tray under their workspace.
- Window titles are hidden. The selected window's title appears under its workspace.
- Sections are always workspaces, entries are always windows, and sort order does nothing. Under `'miniatures` the Lens contract rejects `sections`, `entries` and `sort`.
- When the workspaces do not fit at a readable size, they are shown on pages or shrunk, as `fit` says. Scrolling turns the page.
- Tuning numbers stay out of the config: the readable floor (110 points of workspace height), gaps and badge sizes.
- Known risk: at the 110-point floor a Column on a laptop screen can be about 85 points wide, so two windows of the same app on one workspace look alike until one is selected. The selected window's title, the app icons and Search are the mitigations. Check this on the real build before changing the floor.

**Settings**

- Layout settings live in a `miniatures` record on the Lens. Look settings shared with other Presentations are fields of the Lens itself. Both can be overridden per Display profile through `when.<profile>`; the only profile for now is `"default"`.
- The shipped defaults:

  ```nickel
  lenses.overview = {
    presentation = 'miniatures,
    frozen_thumbnail = 'dimmed,               # 'plain | 'age_badge | 'pause_badge | 'dimmed
    accessory_window = 'enlarged,             # 'enlarged | 'actual_size
    summon_hints = ['label, 'landing_spot],   # any of 'label | 'landing_spot | 'target_workspace
    miniatures = {
      fit = 'page,                            # 'page | 'shrink
      current_workspace = 'highlight,         # 'plain | 'highlight | 'enlarge | 'hide
      arrow_keys = 'nearest,                  # 'nearest | 'by_workspace
    },
  }
  ```

- `fit`: `'page` shows the workspaces on pages; `'shrink` shrinks them to fit.
- `current_workspace`: how the current workspace is marked. `'hide` leaves it out, since it is already visible behind the overlay.
- `arrow_keys`: `'nearest` moves to the nearest window in that direction. `'by_workspace` moves between windows within a workspace with left and right, and between workspaces with up and down.
- `frozen_thumbnail`: how a Frozen thumbnail is marked.
- `accessory_window`: a small window of an Accessory app is drawn with a dashed outline and a "menu-bar app" tag. `'enlarged` grows it to a readable size at its position; `'actual_size` keeps it to scale.
- `summon_hints`: what shows while Summon's modifier is held. `'label` puts "Summon to N" on the selection. `'landing_spot` draws a dashed outline where the window will land. `'target_workspace` outlines the current workspace.
- The contract rejects `current_workspace = 'hide` together with `'landing_spot` in `summon_hints`, because the landing spot is drawn inside the current workspace.

**Selection, keys and Search**

- The Lens's `keys` map applies as in any Lens: `enter` focuses, `shift-enter` runs `summon`. With the mouse, hovering moves the selection, a click runs `enter`'s command and a modifier-click runs the matching modifier binding.
- Arrow keys move the selection as `arrow_keys` says.
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

- `overview` matches every window and uses `'miniatures` with the defaults above.
- It ships unbound in this issue.

## Not in this issue

- The `lens` command, the Lens record and contract, `keys` actions, `summon`, marks, Search matching and ranking, and the `'list` Presentation: Lens core and the `'list` Presentation with Search.
- Raising the deployment target and removing the existing `CGWindowListCreateImage` call sites: Raise the deployment target to macOS 26.
- The strip's use of the cache: Strip Presentation and the cmd+tab takeover.
- The `place` hook and Columns: Column Policy hooks and Column commands, and Fixed Columns: slots, the count invariant, Width presets. Until they exist, a miniature draws the tree positions and the landing spot is wherever the built-in insertion would put the window.
- The key that opens `overview` (`o` in the `lens` leader mode): Default config, Triggers, the `lens` leader mode, `subscribe` events.
- Not built in v1: the `'grid` Presentation. A Lens with `presentation = 'grid` is rejected at load as not yet supported.
- Deferred: the three-finger swipe for `overview` and every other trackpad gesture, Display profiles, and tabs. The shipped defaults are the same on every screen.
- Not specified: how the overlay opens (the real windows animating into their places, or a plain fade). This issue requires no animation.

## Depends on

- Raise the deployment target to macOS 26
- Lens core and the `'list` Presentation with Search

## Open details

Settle each of these while building and note the choice in the PR.

- **The backdrop setting.** The default, the 95% cap and the rejection of darker values are decided. The field's name, its shape (darkness and blur), and whether it sits on the Lens or in the `miniatures` record are not.
- **Capturing before a hide.** A hidden-app window must be captured before the app is hidden, but WinMux does not start a cmd+H. Decide how the capture gets ahead of the hide, or whether the last focus-out capture is what such a window shows.
- **Which API call.** The research recommends `captureScreenshot` (new in macOS 26, no stream per call). The measurements in this issue were taken with `captureImage`. Pick one and re-measure if it is not `captureImage`.
- **Native-fullscreen windows on an inactive Space.** `captureSampleBuffer` works but creates and tears down a stream per call, which has leaked WindowServer memory on some macOS 26 machines. The alternative is to keep the last captured frame or show the icon. Not decided.
- **Throttle interval.** "Throttled per window" has no number. The research also suggests re-capturing on title and resize events; that was not carried into the decision.
- **Telling a Frozen thumbnail from a fresh one.** `frozen_thumbnail` marks only Frozen thumbnails, and a parked Safari window is fresh. How WinMux knows which parked windows are still painting, and so which to refresh when a Lens opens, was not decided.
- **How current-workspace windows are kept live while the Lens is open.** "Live" is decided; the refresh cadence is not.
- **The `'age_badge` and `'pause_badge` looks.** The values exist; only `'dimmed` was chosen and looked at closely.
- **`--presentation miniatures` on a Lens with `sections`, `entries` or `sort`.** The contract rejects those fields on a `'miniatures` Lens at load. What the CLI override does on a Lens that sets them (ignore them, or refuse) was not decided.
- **Capture privacy UI.** No screen-recording indicator appeared during a 48-capture burst in testing, but that was with the grant held by another app. Check whether a signed WinMux build with its own Screen Recording grant shows an indicator during background captures, and report it.
- **Real numbers.** The latency figures come from a stand-in machine with 8 synthetic windows at a virtual display. Re-measure on a real window set of about 50 before tuning.

## Done when

- [ ] Switching away from a workspace captures its windows; opening a Lens afterwards shows their thumbnails with no visible delay.
- [ ] A window that has never been captured shows its app icon.
- [ ] No more than 2 captures are in flight at any time, and opening a Lens with 50 windows does not block on capture.
- [ ] Closing a Lens drops its queued captures, and closing a window drops its thumbnail.
- [ ] `winmux lens overview` opens the `'miniatures` Presentation: every workspace drawn to scale in sidebar order, tiled windows in their real positions, floating windows on top, minimized and hidden-app windows in a tray under their workspace.
- [ ] The current workspace is highlighted, Frozen thumbnails are dimmed, and a small Accessory app window is enlarged with a dashed outline and a "menu-bar app" tag.
- [ ] The selected window's title shows under its workspace, and arrow keys move to the nearest window in that direction.
- [ ] `enter` focuses the selected window. `shift-enter` runs `summon`, and while its modifier is held the selection shows "Summon to N" and the landing spot is outlined.
- [ ] Typing dims non-matching windows in place, moves the selection to the best match, and limits the arrow keys to matches.
- [ ] With more workspaces than fit at a readable size, the Lens pages and scrolling turns the page.
- [ ] Windows on the current workspace keep painting behind the overlay while it is open (check with a terminal running a clock, and with an Electron app).
- [ ] A config that sets the backdrop darker than 95% black fails `winmux config check`.
- [ ] A config with `sections`, `entries` or `sort` on a `'miniatures` Lens, or with `current_workspace = 'hide` plus `'landing_spot`, fails `winmux config check`.
- [ ] `winmux list-lenses --json` shows `overview` with the `'miniatures` Presentation and its resolved settings.
- [ ] `winmux lens <name> --presentation miniatures` opens a configured Lens that sets none of `sections`, `entries` or `sort` as miniatures.

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
