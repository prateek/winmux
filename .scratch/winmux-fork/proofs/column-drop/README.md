# Column drag proof fixtures

The literal Nickel files cover no hook, focused split, focused squeeze, a fixed
Column 3 answer, float and Columns off. Copy one to the guest's isolated active
config and reload it. The three-Column fixture uses workspaces `1` and `2`.

`frames.swift` reads native geometry independently of WinMux. Compile it in the
assigned guest. Its inventory includes auxiliary app windows; compare the ids
in the CLI's managed-window readback, rather than every CoreGraphics window.

`compare-off.sh <vm-script> <guest> <tree> <label> [source-id] [target-id]` is a host driver. Run it once
with the archived base tree and once with the branch tree. Push this directory
to `~/column-drop` first. Both builds need their debug executable and Sparkle
framework, and the branch tree supplies the unchanged Nickel helper. Set
`TART_HOME` before invoking the driver. It sends every guest command through
`vm ssh` and captures the held drag through a separate SSH call.

The comparison defaults to this proof's two retained windows: Zed id 44 and
Ghostty id 49 on a 1280 × 720 display. Supply new ids and adapt pointer coordinates
when staging a different desktop. It starts each build on the literal off
config, waits twenty seconds before the first readback, explicitly moves both
windows to workspace `1` and makes them tiling, then balances horizontal
tiles, drags the right window onto the left window's tab zone, then saves the
overlay, layout readback and native frames under `~/takes/129`.

The Column checks use title-bar `cliclick dd`, `dm`, a five-second hold and
`du`, with a still from another SSH call during the hold. Use a draggable part
of the title bar: Zed's Open Recent Project control opens a menu instead of
starting a window drag. For a full squeeze workspace, focus Ghostty, focus
the empty Column and send Cmd-N with the demo skill's key driver. Wait before
reading once; read-only CLI polling can cancel discovery on the base tree.

The builder's captures and match counts stay with the relay evidence. These
checks use no Lens Search. Final-commit PR demos are a separate pass.
