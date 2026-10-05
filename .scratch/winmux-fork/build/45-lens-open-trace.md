# A trace of a Lens opening, from the key press to the first frame, and the strip's half second

Part of {{UMBRELLA}}.

## What to build

The strip is meant to appear 0.1 s after the key press. In a guest it appears after about 0.5 s, measured by counting frames of a screen recording. Nobody knows where the other 0.4 s goes, because WinMux measures only its own half of the wait.

What is known, from `WINMUX_DEBUG_STRIP_EVENTS=1` on five opens of the build before and after **Lens state, events and effect lifetimes, with controlled time**:

- The session is ready about 8 ms after the key press.
- The draw call is logged at about 105 ms, as the 100 ms display delay intends.
- The strip is on screen at about 500 ms. Nothing logs the first frame, so everything after the draw call is unmeasured: building the SwiftUI view, sizing and ordering the panel, the first layout, decoding and drawing the thumbnails, and the window server putting the frame up.
- A guest at 4 cores and 6 GB showed the same pause as one at 3 cores and 5 GB.

This issue adds one **trace** of a Lens opening, as the person at the keyboard experiences it, and uses it to find the 0.4 s and remove it.

## Decisions

- **The trace runs from the key press to the first frame on screen.** Its start is the key event's own timestamp, not the moment WinMux began handling it, so time spent before the handler runs is in the trace. Its end is the first frame of the Presentation presented by the window server, not the call that asked for it.
- **It names every stage in between**, for all three Presentations: the event reaching WinMux, the binding resolving, the Lens's windows collected, the Filter evaluated in the helper, the session ready, the display delay (strip only), the view built, the panel ordered front, the first layout, the thumbnails for the first frame ready, the first frame presented. A stage that does not apply to a Presentation is absent, not zero.
- **Two ways to read it.** Signposts under WinMux's subsystem, so Instruments and `xctrace` show the stages as intervals beside the system's own; and a command that prints the last openings as a table of stages with their start and duration in milliseconds, as text and as JSON, so a relay builder and a test can read it without Instruments.
- **It is checked against what a viewer sees.** A script films an opening in a guest and finds the frame where the Presentation first appears; the trace's total agrees with the recording to within two frames. A trace that says 110 ms while the recording says 500 ms has not found the first frame, and the issue is not done.
- **It costs nothing when nobody is reading it.** Signposts are off unless a tool is recording; the table keeps a small fixed number of openings in memory. It ships in release builds, since the question that matters is how the installed build feels.
- **The half second is found and fixed here.** The trace names the stage or stages that hold the 0.4 s. If the cause is WinMux's, this issue fixes it. If it is the guest's (no GPU, a slow first composite), the issue shows that with the same trace from a build on the host, and says so.
- **It replaces the ad-hoc log.** `WINMUX_DEBUG_STRIP_EVENTS`'s `strip ready … elapsed=` and `strip draw elapsed=` lines are stages of the trace afterwards. The flag-event lines it also prints stay until the keystroke issue below no longer needs them.

## Not in this issue

- Tracing anything but a Lens opening: Search, selection moves, Summon, layout refresh. The stage names and the reader are built so those can be added.
- A performance budget enforced in CI. A guest's timings are too noisy to gate on.
- Any change to the 0.1 s display delay itself.

## Depends on

- **The Tile: one drawing of an entry, shared by every Presentation**. It rewrites what the first frame draws, so the baseline is taken after it.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **The command.** `winmux debug-lens-trace [--json] [--last <n>]`, beside `debug-windows`.
- **The first frame.** A `CADisplayLink` or `CATransaction` completion on the panel's layer after the first layout, or the hosting view's first `viewDidDraw`; whichever agrees with the recording. Say which was tried.
- **The key press's timestamp.** `NSEvent.timestamp` for a panel key, the Carbon event's time for a global binding, and the client's send time carried in the request for a CLI open.
- **The film check — changed.** A centre pixel probe and a straight strip-edge guard over `trace-film`'s ScreenCaptureKit movie. The edge guard rejects workspace motion that changes centre pixels before the strip arrives. Immutable pixel copies and their measured first-sample Mach stamp establish frame zero; `keys` logs the posted event stamp on that clock. The helper rejects encoded timestamp corruption and verifies the output's real 60 fps rate before comparing frames. The old `screencapture`/wall-clock origin was not a frame-zero measurement.
- **Measure before changing anything — changed by the driver.** Open the strip five times in one process, with its first-ever Lens as the first row, and compare: a cost paid once per process (SwiftUI's first layout, fonts, the glass effect compiling) shows as a slow first opening and a fast second, and every filmed take so far started a fresh process. Then look at the recording frame by frame: the strip draws placeholders until thumbnails publish, so the 0.5 s may be the thumbnails arriving in a panel that was already up.
- **Suspects in the code.** The panel calls `setFrame(display: true)` before it assigns the hosting view's `rootView`, so the synchronous draw is of the empty view and the strip's first frame waits for a later run-loop turn. Thumbnail polling starts only after the Presentation is presented. `strip draw` is logged before `show()` is called, not after it returns. Then the first `NSHostingView` layout of a view tree never built before, `GlassSurface` compiling on first use, and the window server in a guest with no GPU.
- **Where the stages live — changed.** `LensLifecycle` owns the active trace, delay and cancellation. `LensCommand` measures collection/Filter work where it happens, and the panel measures AppKit preparation/order/display through the same trace. A separate bounded store owns the reader and injectable stamp source; profiling does not move command or AppKit work into the lifecycle.

## Build result

The trace and reader were committed before any timing change, and the before guest build comes from that instrument-only commit. First layout held the cold cost. The view now assigns its real root before sizing, lays out while hidden during the strip's existing display delay, and orders only at its original 100 ms deadline. Startup drawing warms all three Presentations using existing window snapshots and cached pictures; an empty desktop uses neutral picture, placeholder and workspace-badge branches. It neither orders a panel nor requests fresh thumbnails. Full bitmap rasterization is confined to startup; ordinary openings use the hosting display pass.

Decided: use Mach absolute seconds, excluding sleep. Carbon and NSEvent timestamps use that timebase; CG nanoseconds convert centrally. The CLI carries its send time across the same-machine socket because both processes share the kernel clock.
Decided: use the hosting view's display link after the render tick and two following compositor cycles, calibrated against the film. `viewDidDraw` was unreliable on repeated layer-backed openings; a one-tick signal was early. AppKit exposes no public first-window-composite acknowledgement, so the signal is an observation proxy, not a hardware guarantee.
Decided: use immutable ScreenCaptureKit receipt-time samples and audit every encoded timestamp. The guest's source display timestamps and a reordered H.264 take did not provide a trustworthy movie origin.
Decided: warm existing window-card branches at startup, falling back to neutral branches on an empty desktop. This shifts cold rendering out of the first gesture, without changing the 100 ms delay or starting thumbnail capture.
Decided: measure stages at their existing owners, with one trace passed into LensLifecycle and a separate bounded reader store. This avoids moving collection, Filter or AppKit work merely to instrument it.
Decided: retain twenty openings, default to the last five, and mark cancelled openings explicitly. Signposts use WinMux's subsystem and `lens-opening` category, gated by Instruments' dynamic recording category.

The final default-size five-opening film agrees within two frames (maximum 20.323 ms, at most one frame index). Its trace totals are 139.842–157.254 ms, with visible delivery 128.591–175.402 ms. The 4-core/6144-MB take still has 40–63 ms after ordering; its first total disagreed by 97.616 ms (10.621 ms input-origin shift and 86.995 ms endpoint disagreement) while the desk was moving, so that take is diagnostic, not calibration acceptance. A settled repeat stopped on the image's `com.apple.sshd-session` direct-display/private-picker permission prompt; it was not granted. The remaining guest post-order time includes compositor delivery and the calibrated observer. No host desktop build runs in the relay. Prateek's host check after landing, on his installed dogfood build: hold Cmd and press Tab five times, releasing Cmd between openings, then run `winmux debug-lens-trace --last 5`. Compare `first frame presented` duration and each opening's total with the guest's tables. The 150 ms/host comparison item stays unticked until that reading; installed build, a second display and real sleep/wake/unlock also remain his checks.

How to record and read the stages, including Instruments and the film check: [Lens opening traces](../../../docs/lens-opening-traces.md). The new command replaces the strip ready/draw elapsed log; `WINMUX_DEBUG_STRIP_EVENTS` still prints flag events.

## Done when

- [x] Opening the strip, the list and `overview` each records a trace whose stages cover the key press to the first frame with no unnamed gap over 5 ms.
- [x] `winmux debug-lens-trace` prints the last openings as a table and as JSON; a test drives an opening on the controlled clock and reads the stages in order.
- [x] The stages show as intervals in Instruments or `xctrace` from a debug build in a guest; the pull request has the screenshot.
- [x] In a guest, the trace's total for the strip agrees with a screen recording of the same opening to within two frames, over five openings.
- [x] The pull request names where the 0.4 s went, with the table before and after.
- [ ] The strip is on screen within 150 ms of the key press in a guest, or the pull request shows with the same trace why a guest cannot do it and what a host build does.
- [x] `docs/` says how to record and read a trace.

## Sources

- The live runs of **The `vm` skill: two guests at most on the build machine, each at a fixed small size** and of **Lens state, events and effect lifetimes, with controlled time**, in pull requests [#70](https://github.com/prateek/winmux/pull/70) and [#73](https://github.com/prateek/winmux/pull/73).
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
