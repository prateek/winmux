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

## Sources

- Pull request [#82](https://github.com/prateek/winmux/pull/82), **Decisions the relay made** and **Declined**.
- `docs/lens-opening-traces.md`.
