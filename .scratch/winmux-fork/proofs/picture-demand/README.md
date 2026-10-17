# Drawn-pixel capture proof

Run every desktop operation in the issue guest through the repository's `vm` wrapper.
Keep its display at 1920 × 1080. These scripts use scratch config/state, owned stage
windows and TextEdit. They never grant a permission or change a guest's display.

- `stage.swift` is the demo skill's stage with five controlled window shapes.
- `winmux.ncl` floats the staged windows on one workspace and gives grid films an Option-G chord.
- `run.py BUILD COUNT TRIAL` measures physical footprint outside, after an eight-second grid
  refresh, and five seconds after dismissal; it writes screenshots, traces and readbacks.
  `stage-desk.py COUNT` prepares the controlled windows first.
- `openings.py BUILD TRIAL` starts a fresh process and films five grid openings with `trace-film`.
  Check every take with `check-lens-film.py --presentation grid --opening-key '⌥ G'
  --probe 600,800,80,80`. Inspect the probe frames; it lies on the panel surface beside pictures.
- `visible.py BUILD` compares the three-window grid with small text in TextEdit. Stage two
  controlled windows first. `resize-text.swift` fixes the text window's frame before priming
  the native-frame cache.
- `presentations.py` checks picture list, miniatures, departure after closing and a Frozen Tile.
- `minimize.py` checks minimization and restoration after the final grid refresh; compile
  `native-minimize.swift` first for direct AX state readback. Ordinary `list-windows --all`
  omits the native-minimized window, so it is not the restoration lookup.
- `final-live.py` checks the final grid and an actually capped 180-by-120-pixel strip window.
- `stills.py DIRECTORY` makes lossless host-side comparison crops with Pillow.
- `analyze.py DIRECTORY` audits demand/capture/window bounds from the unified capture log and
  prints the three-run memory medians. `display.swift` records display size and backing scale.
- `pin-baseline.py` installs the identical no-demand regression in the base test suite, so its
  original API and the branch run the same legacy-size assertion.
- `instrument-base.py` adds only size logging to the archived base tree, leaving its capture
  policy unchanged. Initialize Git in both guest source trees before launching debug binaries.

The base is the issue's pinned `33a327ee` tree, copied to the guest's `winmux-base` directory; the branch
uses `winmux`. Both run through the same drivers. Keep the raw footage, sample clocks, event
logs, traces, memory reports, capture logs and end-state screenshots in the private evidence
bundle. The builder report records the measurements and recorder/checker limitations.

The capture regressions also cover demands above the native cap (priority uses raw drawn
demand, repeated equal requests coalesce), departure promotion during the throttle, retaining
coalesced Lens owners and minimizing behind an older small capture. That last case waits for
the requested size or the existing 200 ms deadline. Timing/memory scenes have no pending
minimize waiter, so the final waiter-only fix does not change their capture paths.

The measured 1× text picture grows from 583 × 295 to 614 × 310 pixels for a
613.1 × 309.7 drawn picture. Forty-window grid captures shrink to at most 190 × 99
pixels; total physical footprint does not fall in these runs. The unmodified film checker
flags late third-tick estimates on both builds; retain its failures alongside the tables.
