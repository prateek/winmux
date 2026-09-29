# Research: live thumbnails for parked windows, and AltTab's implementation

Type: research
Status: resolved

## Question

WinMux (like AeroSpace) hides windows on inactive workspaces by parking them off-screen. Can ScreenCaptureKit (or CGWindowList fallbacks) capture current content of off-screen, minimized, and hidden-app windows? At what cost and latency for roughly 50 windows? Study AltTab's source (GPL-3, for design only, no code copying): how it enumerates windows across Spaces and screens, its thumbnail capture and cache pipeline, how it keeps opening fast, how it orders MRU, and which of its design choices (per-shortcut filters, app-vs-window grouping, hold-to-cycle) map onto the Picker model in `CONTEXT.md`. Also note how WinMux's `SwitcherPalette` HUD is built today. Deliverable: a thumbnail strategy recommendation, plus a list of AltTab design choices worth adopting.

## Answer

- ScreenCaptureKit one-shot capture on macOS 26+ works for parked (partially off-screen) and minimized windows. Hidden-app (ordered-out) windows can't be captured, and fullscreen windows on an inactive Space need `captureSampleBuffer`. `CGWindowListCreateImage` is obsoleted in the macOS 15 SDK and can't capture minimized windows.
- Cost: the OS serializes captures at roughly 40 ms each (AltTab measured 43 windows in 1.7 s), so 50 windows take about 2 s. The Picker can never wait on capture.
- Strategy: cache a thumbnail-sized frame per window on WinMux's `Window`. Capture on park and on focus-out, throttled. Render the Picker from the cache immediately and refresh visible tiles first behind a 2-in-flight gate. Fall back to the app icon.
- Caveat: an app may stop painting a parked window whose last on-screen pixel is covered, so thumbnails may show the last painted frame rather than live content. Unverified.
- AltTab ideas to adopt: per-binding filter knobs as the built-in Filter vocabulary, sort kept separate from Filter, grouping modes, release styles (focus, hold, search), a 100 ms strip display delay, a non-activating strip panel, and MRU written only on confirmed focus. WinMux has no global MRU yet.

[findings](../research/03-thumbnails-and-alttab.md)
