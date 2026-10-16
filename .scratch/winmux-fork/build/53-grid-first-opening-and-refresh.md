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

- [ ] `winmux debug-lens-trace` over five grid openings of a fresh process shows the first within 50 ms of the others, with the stage that held the 548 ms named in the pull request.
- [ ] The pull request has the refresh measurements for forty windows, and the decision they led to.
- [ ] Startup drawing's duration, before and after, is in the pull request.

## Built measurement support; acceptance incomplete

`debug-lens-trace` records per-session thumbnail requests, successful completed
captures and presented duration in text and JSON. Requests coalesced by the gate
still count as requests; only successful captures started for that session count
as completions, and dismissal freezes the totals. An opt-in
`WINMUX_DEBUG_LENS_FRAMES=1` display-link observer reports intervals over 1.5
refresh intervals and the longest interval. It creates no sampling link when off.
Controlled-clock, injected-tick and controlled-capture tests cover the readers,
ownership, coalescing, failure and dismissal. Grid and strip refresh expectations
are unchanged.

The first valid base process on the rich desk reproduced the excess in `view
built`: 1,140.6 ms total, with 985.8 ms in that stage; later totals were 145.5,
189.6, 145.1 and 219.7 ms. Startup drawing took 966 ms. Default startup settings
already match the shipped windows Lens: real sizing, card Tiles, workspace
sections. This excludes a settings mismatch, but does not distinguish empty-desk
warming from the other real-opening differences.

A Python Local Network permission prompt interrupted restaging. It was preserved
and left unanswered. The full six-process base comparison, a verified opening
fix, the branch's timing tables and film, startup before/after comparison and
forty-real-window release measurements remain unchecked. No refresh decision can
be drawn from these data; no refresh schedule or startup drawing was changed.
Installed-build checks, a second display and real sleep/wake/unlock remain
Prateek's.

## Sources

- Pull request [#82](https://github.com/prateek/winmux/pull/82), **Decisions the relay made** and **Declined**.
- `docs/lens-opening-traces.md`.
