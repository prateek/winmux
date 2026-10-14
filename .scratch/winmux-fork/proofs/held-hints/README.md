# Held-hint proof tools

Run these only in the driver’s assigned guest, through the repository’s `vm` wrapper. Export the driver-provided `TART_HOME` before each host shell. Keep the guest’s display, grants and disk intact. The standing desk must already have its four windows, with Zed/Ghostty on workspace 1 and Safari/Notes on workspace 2.

Push this directory to `held-proof` with `vm push`. Through `vm ssh`, compile `keys-check.swift` with `swiftc -O keys-check.swift -o keys-check`. It extends the demo key driver with three proof steps:

- `snap:<name>` waits 400 ms and saves a screenshot, trace text/JSON, focused workspace/window and every window’s workspace under `~/captures/<name>.*`.
- `profile:<name>` installs the matching `.ncl` and reloads config without sending another input event.
- `click:<x>,<y>` clicks with the modifiers this same process holds.

A chord, its holds, snapshots and release stay in one invocation. `keys-check 0 ~/captures/events.json down:alt tap:slash snap:list/opening up:alt down:alt snap:list/shown up:alt snap:list/hidden tap:escape tap:escape` checks the Search list. The event timestamps use the supplied recording start; zero is sufficient for builder stills.

`live.ncl` imports the shipped Lens settings, opts in Cmd-Tab, and adds a held picture grid on Control-Option-Tab, a held Search strip on Control-Shift-Tab, and the Option-Tab strip exception. `search-strip.ncl` reuses the earlier filming query `len saf`; `live.ncl` uses the shorter `saf` for the action probe. Both match Safari once. `always.ncl`, `changed.ncl` and `cards.ncl` isolate always-visible hints, the Control hints key/changed close binding, and card Tiles.

`restart.zsh [source-directory]` restarts the debug build and primes the desk. Inspect section headings; after the known restart defect, switch to workspace 2, pause, and switch back before accepting a take. `unchanged.zsh <capture-prefix>` checks eight real actions with readbacks. Run that same script once against an archived base built in a separate guest directory and once against the feature build. Set `WINMUX_PROOF_ROOT` to that directory for the base. It checks Enter, Alt-Enter, held Shift-Enter in list/grid, Option-click in grid/strip, and plain/Option strip release.

The proof tools do not grant permissions or publish anything. Final-commit PR demos belong to the driver’s separate demo pass.
