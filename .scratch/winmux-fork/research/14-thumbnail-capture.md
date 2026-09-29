# Task 14: thumbnail capture measurements

Ticket: [14-task-measure-thumbnail-capture](../issues/14-task-measure-thumbnail-capture.md)
Date: 2026-09-29
Harness and raw output: [prototypes/14-thumbnail-harness/](../prototypes/14-thumbnail-harness/) (`main.swift`, `clock.html`, `bench1.txt`, `bench48.txt`, `stale1.txt`, `translucent.txt`)

## Setup, and how it differs from the ticket

- **Machine:** a Mac mini M4 (`Mac16,10`) on macOS 26.4.1, driving one 1920×1080 virtual display at 1× (CoreGraphics vendor `unkn`, model `virt`, so probably a headless or screen-sharing display). This is not Prateek's laptop and ultrawide. Capture cost should transfer roughly, since it's the same Apple Silicon generation, but the 1× scale means "native" captures here are half the pixels of a Retina window.
- **Window set:** only two real app windows were open (Orca and a Safari window). I opened throwaway windows to get samples: four Chrome windows on a temporary profile showing a clock page, two Ghostty windows running a `date` loop, a Safari tab with the clock page, and later VS Code rewriting a file every 250 ms. So the latency set is 8 windows, and the 48-window run captures those 8 six times each. The ticket asked for about 50 real windows; this is a synthetic stand-in.
- **Session:** not locked, on console, display awake. Screen Recording was already granted to the host (Orca). No "bypass the private window picker" alert was observed, but nobody was watching the screen.
- **Capture call:** `SCScreenshotManager.captureImage` with `SCContentFilter(desktopIndependentWindow:)`, `showsCursor = false`, `ignoreShadowsSingleWindow = true`, and an explicit width (320 px thumbnail or the window's native size). Content list from `SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)`.

## Latency

| Measurement | Result |
|---|---|
| `SCShareableContent` fetch (180 SCWindows) | 30 ms cold, 27 ms warm |
| First capture after process launch | 113 ms |
| Warm capture, one in flight | p50 33 ms, p90 37 ms, max 40 ms per window. Size doesn't matter: 320 px and native are the same. |
| 8 windows | 1 in flight: 265 ms. 2 in flight: 180 ms. 4 or 8 in flight: 180 ms. |
| 48 captures | 1 in flight: 1.60 s. 2 in flight: 1.03 s. 4 in flight: 1.01 s. |

Captures are serialized by the system after the second: with 2 in flight the throughput is about 21 ms per window, and adding more only makes each capture wait longer (p50 of 83 ms at 4 in flight, 105 ms at 8). So the 2-in-flight gate from the thumbnails research is the right number, and a full refresh of 50 windows costs about 1.1 s. The Lens can't wait on it, as already decided. AltTab's reported 40 ms per window serial matches (33 ms here).

The content fetch is 30 ms and sits on the Lens-open path if the Lens has to resolve `SCWindow`s at open. Cache the `SCWindow` list and refresh it on window-created and window-destroyed events instead.

## Do apps keep painting when covered?

Method: raise the target window, capture twice 2 s apart, then cover it with a borderless opaque black panel at floating level (4 px larger on every side) and capture at 1–3 s and 8–10 s, then uncover and capture again. "Changed" is the fraction of pixels (on a 320 px downscale) that differ between the two captures of a pair. The content changes every 100–250 ms, so a live window always shows a large change. A second run left the window's leftmost 1 px column uncovered, which is what a parked window with its one visible pixel looks like.

| App | Fully covered | One pixel column visible | After uncovering | Blank? |
|---|---|---|---|---|
| Chrome (clock page) | Frozen within 1 s: changed 0.000. Page reports `visibilityState` hidden. | Live (0.90) | Live again within 0.3 s | No, last frame kept |
| VS Code (Electron) | Frozen: 0.000 | Live | Live again within 0.3 s | No |
| Ghostty (AppKit + Metal) | Frozen: 0.000 | Live | Live again within 0.3 s | No |
| Safari (clock page) | Still changes across a 2 s gap (0.94–0.98), although the page reports `visibilityState` hidden. Timers are probably throttled, but it keeps painting. | Live | Live | No |
| Orca | Inconclusive: nothing in its window changed during the test | | | |

Covering with a **non-opaque** panel (`isOpaque = false`, black at 85% alpha) did not freeze Chrome: it stayed live through 10 s. That fits the window server counting only opaque windows as occluding, but it was observed on Chrome only.

Stale captures are the last painted frame, never blank or black. The apps stop drawing when the window server reports them occluded: Chrome-family browsers, Electron apps and native Metal views all do, and only Safari (of the apps tried) keeps going.

## What this means for the design

- **Parked windows are usually frozen.** WinMux parks a window with 1 px visible in a bottom corner of the monitor (research 03 §1). Tiled windows normally cover that corner, so a parked Chrome, Electron or Metal window is fully occluded and stops painting. A capture taken later returns the frame from the moment it was covered. Capture-at-park is therefore the only capture worth taking for most parked windows; re-capturing them on Lens open just repeats the same frame at 33 ms each. Safari windows are the exception and can be refreshed.
- **So capture-at-park is good enough, and there's no race.** A capture taken after the park still returns the park-time frame, because covered windows keep their last painted frame. What fails is refreshing a covered window later. The one real race is hidden-app (cmd+H) windows, which can't be captured at all once ordered out (research 03), so capture those before the hide. Show thumbnails of parked windows as "as of when you left it", which is what the grid prototype should design for.
- **The grid Presentation should use a non-opaque panel.** An opaque full-screen grid would occlude every visible window, and they'd all stop painting within a second of the Lens opening, so even the currently visible windows would go stale. A translucent panel kept Chrome live; the grid prototype should confirm Electron and Metal apps, and whether a near-opaque backdrop (alpha close to 1 with `isOpaque = false`) still counts as non-occluding.
- **Keep the refresh gate at 2 in flight**, and cache the `SCShareableContent` window list rather than fetching it on open.

## Screen-recording indicator

Menu-bar screenshots before, during and 12 s after a 48-capture burst are identical: no purple screen-recording indicator appeared (an orange microphone dot was already there). This was on the virtual display, with Screen Recording granted to the host app. It's one observation for the "Capture privacy UI" fog item, not a verified answer: a signed WinMux build with its own grant may behave differently.

## Not measured

- A real 50-window set on Prateek's laptop and ultrawide at 2× scale. Native-size captures may cost more at 2×; 320 px thumbnails probably won't.
- Truly parked geometry (moving a window off-screen with AX) instead of an overlay cover. The overlay test models the same window-server occlusion, but I didn't move Prateek's windows.
- Minimized windows, Slack, Orca with changing content, and other Electron apps with `backgroundThrottling` turned off, which may keep painting.
