# Task: measure thumbnail capture on Prateek's machine

Type: task
Status: resolved

## Question

Is capture-at-park-time good enough for grid thumbnails? With Prateek's real window set (about 50 windows), measure ScreenCaptureKit one-shot capture latency, cold and warm. Check whether Chrome, Electron apps and Safari keep painting a parked (off-screen) window once its one visible pixel is covered, or whether their captured content goes stale or blank. A small throwaway Swift harness is enough; the agent can drive it (AFK), and Prateek only needs to grant Screen Recording.

## Answer

Yes, capture-at-park is good enough. A capture taken after the park still gets the park-time frame, because a covered window returns its last painted frame; what doesn't work is re-capturing it later to refresh it. Measured on a Mac mini M4 with a virtual 1080p display and 8 throwaway windows, not Prateek's laptop and real window set, so the latency figures are a stand-in.

- Cost: 33 ms per capture serially (320 px or native, same), 113 ms for the first one after launch. Two in flight gives about 21 ms per window; four or eight give nothing more. 48 captures take 1.6 s serially and 1.0 s with 2 in flight. The `SCShareableContent` fetch is 30 ms, so cache it rather than fetching on Lens open.
- Staleness: Chrome, VS Code (Electron) and Ghostty stop painting within a second of being fully covered by an opaque window and resume within 0.3 s of being uncovered. Captures of a covered window return the last painted frame, never a blank. With one pixel column showing, all keep painting. Safari keeps painting even when fully covered.
- Because WinMux's park pixel normally sits under a tiled window, most parked windows are frozen, and re-capturing them on Lens open only repeats the frame from park time. Safari is the exception.
- A non-opaque cover (85% black) did not freeze Chrome (only Chrome was tried), so the grid panel should be non-opaque or every visible window goes stale when the grid opens.
- Hidden-app (cmd+H) windows are the one case with a race: research 03 found they can't be captured once ordered out, so capture them before the hide.
- No screen-recording indicator appeared during a 48-capture burst (one observation, virtual display).

[findings](../research/14-thumbnail-capture.md) · [harness](../prototypes/14-thumbnail-harness/)
