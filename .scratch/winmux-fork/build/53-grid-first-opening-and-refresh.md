# The grid's first opening, and what refreshing every Tile costs

Part of {{UMBRELLA}}.

## What to build

Two costs of the `'grid` Presentation were seen and not measured.

- **One slow first opening.** The first grid opening on the fourteen-window desk took 548 ms to its first frame; the next four took 106 to 196 ms. Startup drawing prepares the grid, so the first opening should be like the rest. Startup drawing uses default Lens settings, and the shipped grid Lens sets `tile-size = 'real`; that is the first thing to check.
- **Every Tile refreshes every 500 ms.** A strip refreshes nine at most. A grid shows every match, so it asks for a picture of every window that is not Frozen, twice a second. The capture gate bounds how many run at once. Nobody has measured forty real windows.

Measure both with the opening trace, fix the first, and decide the second from the numbers.

## Decisions

- **The first grid opening of a process is within 50 ms of the later ones**, on the fourteen-window desk, in the trace and on film.
- **The refresh is measured before it is changed**: captures per second, WinMux's CPU, and dropped frames while a grid of forty windows stays open for thirty seconds. The pull request shows the numbers.
- **If the refresh costs more than one core's tenth**, the grid refreshes the selected Tile and its row every 500 ms and the rest every two seconds. Otherwise it stays, and the pull request says so.

## Not in this issue

- The 582-point cap on a saved picture.

## Depends on

Nothing.

## Done when

- [x] `winmux debug-lens-trace` over five grid openings of a fresh process shows the first within 50 ms of the others, with the stage that held the 548 ms named in the pull request.
  Six branch processes: maximum excess +29.4 ms; calibrated film excess +25.0 ms; base excess in `view built`.
- [x] The pull request has the refresh measurements for forty windows, and the decision they led to.
  3 valid release sets: median 0.06562 of one core; refresh stays at 500 ms for every live Tile.
- [x] Startup drawing's duration, before and after, is in the pull request.
  A: 966/589/605 → 741/446/447 ms; B: 1490/743/713 → 966/799/781 ms.

## Built and measured

The six fresh-process branch comparisons pass the first-opening bound: scenario A
excesses are +11.5, −21.2 and +29.4 ms; scenario B excesses are
+5.4, −14.4 and +7.8 ms. Each process has five key-triggered openings after one workspace warm.
The calibrated fresh-process film passes the unchanged two-frame checker:
177.9 ms first visible against a 152.8 ms later median, an excess of 25.0 ms.

The base reproduced a 1,140.6 ms first opening, including 985.8 ms in `view built`.
Smaller timed/profiled reproductions locate synchronous panel sizing through
`NSHostingView.layout`, SwiftUI view-graph transactions and nested ZStack sizing;
the original 986 ms event itself was not captured under Time Profiler. Startup
settings already match the shipped grid's real sizing, card Tiles and workspace
sections. Startup now draws fourteen varied picture/placeholder Tiles in four
sections on an empty desktop and displays/flushes the hidden native backing once.
It orders no panel front and requests no fresh capture. No second warm remains.

Startup drawing, base → branch in milliseconds: A 966/589/605 → 741/446/447;
B 1490/743/713 → 966/799/781. No paired branch increase exceeds 100 ms.

`debug-lens-trace` retains requested/completed captures and presented duration.
Capture completions belong to the Lens token that started the screenshot;
dismissal freezes totals. `WINMUX_DEBUG_LENS_FRAMES=1` enables an interval
observer: intervals longer than 1.5 refresh intervals and the longest interval.
With the flag off, no sampling display link is created. Controlled-clock,
controlled-capture and injected-tick tests cover these behaviors. Representative
grid and hidden-backing tests fail with their fixes undone; all pre-existing
preparation, grid and strip tests remain unchanged.

Forty real windows, eleven live and twenty-nine Frozen, were measured on the
signed release dry run from `5aa960c0`, at four cores, 6144 MB and 1920×1080.
The 3 accepted sets have a median refresh share of 0.06562 of one core,
below 0.08 and the 0.10 threshold. The refresh stays unchanged. Captures per
actual presented second range from 20.85 to 21.18; requested
session-count/30 rates, CPU deltas, guest idle and frame intervals are in the pull
request. The frame observer and refresh were not changed for the observed long
intervals; no total session frame count is recorded.

The first opening on an installed build, and the grid's smoothness on real hardware, are in Prateek's checks.

## Sources

- Pull request [#82](https://github.com/prateek/winmux/pull/82), **Decisions the relay made** and **Declined**.
- `docs/lens-opening-traces.md`.
