# Native sidebar tree checks

Run these tools only in an assigned guest, through the VM skill's SSH transport.
Set `TART_HOME` in every host shell. Keep the guest's disk and display intact, grant
no permission prompt, and leave it running when finished. Debug WinMux never runs
on the host desktop.

Push the demo skill's `desk/` to `~/desk` and this directory to
`~/sidebar-tree-proof`. Build `ui.swift` as `ui` there. After syncing and building
WinMux, stage the fourteen-window rich desk at 1920 × 1080. Set `WINMUX_CLI` to
`~/sidebar-tree-proof/quiet-cli` for staging: until the read-only refresh defect
is fixed, it leaves discovery quiet before each read. The helper's command timeout
is five seconds, so its delay is three seconds.

Save the starting inventory and layout with:

```sh
python3 ~/sidebar-tree-proof/live.py snapshot original
```

Hover at x=8 to cross the native deep-edge threshold, then use `clicklabel` to pin
the sidebar. `live.py` finds controls through accessibility, waits after pointer
movement for mouse passthrough to update, captures held previews and final states,
then reads WinMux once after a fixed quiet interval. It uses no readiness polling.

Run the flat sibling cases before enabling levels:

```sh
python3 ~/sidebar-tree-proof/live.py draglabel flat-before desk 'winmux.ncl — winmux.ncl' before 1 0
python3 ~/sidebar-tree-proof/reset-desk.py
python3 ~/sidebar-tree-proof/live.py draglabel flat-after desk 'winmux.ncl — winmux.ncl' after 1 0
python3 ~/sidebar-tree-proof/reset-desk.py
```

Then run `drops.zsh`, `invariant-drops.zsh`, `search.zsh`, `defaults.zsh` and
`widths.zsh`. Search starts with both levels visible and all disclosures open.
The scripts save captures and native readbacks under `~/takes/sidebar-tree`.
Restaging reuses the original managed windows and asserts their exact inventory;
directional moves explicitly stop at workspace boundaries.

`paired.zsh` requires a separately built base tree at `~/sidebar-base`, including
its helper and adjacent Sparkle framework. It runs `unchanged.zsh` against both
builds and exercises the same native Place hook. `WINMUX_CLI` can select that
build for `live.py` and `reset-desk.py`.

After `lifecycle.zsh` restores and captures a fresh rich desk, `paired-inputs.zsh`
compares the native Column command, tab-strip reorder and on-screen window drag
against that new fixture on both trees. Its pointer coordinates are for the
1920 × 1080 rich desk; validate the resulting native trees before accepting it.

After pulling the captures, run `verify-live.py <captures>` and
`verify-search-defaults.py <captures>` and `verify-paired-widths.py <captures>`.
A take script's exit code alone is not
acceptance: these validators check native ordering, membership, refusal reasons,
unchanged layouts, Search paths, disclosure restoration and effective toggles.
`measure.swift` combines native accessibility frames with the rendered font sizes
to estimate clipping; inspect the matching screenshots too. The shorter-height
take uses the existing menu-bar reserve setting, preserving guest resolution.

Quit debug WinMux and close the staged apps after the final readback. The driver
owns final-commit demos, CI, publication and guest deletion.

## Final builder regression takes

With a fresh `original` snapshot of the rich desk, run `search.zsh`,
`pass2-core.zsh`, `pass2-extra.zsh`, then `pass2-size.zsh`. The extra takes need
`../peek/window-frame.swift` pushed to `~/peek-proof`; that existing AX helper
prepares a floating terminal at 500 by 320. `pass2-size.zsh` records independent
CoreGraphics frames before tiling, after tiling and after the floating drop.
The agent inventory can retain a previous frame during post-drag observer
suppression, so use those native reads with the screenshots to verify size.
Each drop still saves `list-windows` and the agent tree.

Run `verify-pass2.py <captures>` after pulling the takes. It checks sibling and
Column-child order, whole-container moves/cancellation, group joining, search
counts/paths and disclosure restoration, scrolled controls, remembered floating
size and the final fourteen-window reset. Inspect the window-row on-screen
overlay and scrolled-header screenshots as well.
