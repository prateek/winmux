# Landing and placement edge-case probes

Run these only in the builder's designated guest, through the `vm` skill. Build
both trees there first: the branch in `~/winmux`, and the base in a separate
source directory. The base archive needs its own `.git` directory before launch.
The guest must already have the driver's permission grants; grant nothing.

Prepare `~/demo/landing76/LandingStage` from the demo skill's `stage.swift`, removing
its `setWallpaper()` call, and compile `keys.swift` beside it. Copy these scripts
to `~/demo/landing76/proof/`. Pass the checkout directory and a capture label to
each script:

```sh
bash ~/demo/landing76/proof/stage.sh ~/winmux-base base
bash ~/demo/landing76/proof/placement.sh ~/winmux-base base
```

Repeat with `~/winmux branch`. Run `stage.sh` again before `reload.sh` so both
recordings start with flattening off and the same Column layout. Use a fresh
capture label when repeating a recording: the recorder refuses to overwrite.

`stage.sh` launches only owned Red, Blue, Green and Orange windows. All initially
join Column 2. Red moves to Column 1, Orange to workspace 2, and Green closes,
leaving Blue alone in a tab-group wrapper in Column 2. Fixed waits precede
readbacks because read-only commands can cancel the refresh that registers a
new window on the base.

`placement.sh` records that state under float and squeeze, along with the
hook-only dry-run decision. `layout tiling` on the survivor declines the no-op
before `relayoutWindow`; it does not execute Place. The script finishes with
flattening on and records Columns, parent layouts and the same dry-run decision.
Compare window counts per Column and titles/layouts, excluding ephemeral IDs.
These transcripts do not claim to demonstrate actual re-placement. The real-tree
tests in `LandingPlacementEdgeCasesTest` carry that proof for all four policies.

`reload.sh` selects Orange with Search, holds Option in one input process, films
a config save turning Columns off, and reads back config status, the held and
closed Lens traces, Columns and final windows. Search has exactly one match,
Orange on workspace 2. The base keeps its squeeze hint; the branch redraws the
ordinary landing with the same selection/modifier. Captures go to
`~/takes/landing76`. Close the debug app and owned windows after collecting them.

A one-display guest cannot demonstrate the cross-display floating fix. The
synthetic-monitor tests compare hints with the frames obtained through the real
Summon command and following layout, with equal and unequal display sizes and
both incoming tiling and already-floating windows.
