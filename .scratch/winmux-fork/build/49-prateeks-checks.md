# Prateek's checks on an installed build and real hardware

Part of {{UMBRELLA}}.

A guest cannot show a signed release build, a real keyboard, a second display, or a real sleep, wake or unlock. Each line below is a check a build issue left for Prateek. Tick it when it passes; comment when it does not, and the next driver turns the comment into an issue.

A driver adds a line at Land, under the issue that left it, with the exact steps and what a pass looks like.

## From the second build

**A trace of a Lens opening**
- [ ] Hold Cmd-Tab five times, then run `winmux debug-lens-trace --last 5`. `panel ordered front` ends near 107 ms in every row, the first included.
- [ ] After a launch, read the `Lens startup preparation took` line in the unified log, category `lens`, and note the duration on your display. It was 170 to 350 ms in a guest at 1280 by 720.

**The Hold**
- [ ] On a real keyboard: Cmd-Tab, keep Command down, press Tab three times, release. The selection moves at each press and the window selected at release is focused. Every key in the guest was a posted event.

**The `'grid` Presentation**
- [ ] Open a grid Lens with three windows on the ultrawide. If the pictures look blurred, say so here: the picture is saved at most 582 points wide and a large Tile stretches it.
- [ ] After a fresh launch, open a grid, then run `winmux debug-lens-trace --last 1`. One first opening took 548 ms in a guest and the stage that took it is not known.

**Sections**
- [ ] On two displays, open a list or grid with `--sections monitor`. Each display has its own Section. Tests only so far.

**The strip opens off the main thread in a release build**
- [ ] On the installed build `0.5.6-dogfood.13` or later, hold Cmd-Tab for a second, ten times. WinMux is still running after each, and `ls ~/Library/Logs/DiagnosticReports | grep WinMux` shows no new report. `.12` crashed on the first hold.

**The strip as one row of the grid**
- [ ] On the installed build, hold Cmd-Tab with twelve or more windows open. Every window is in the strip, in two or more rows, with no "+N"; Tab steps from the end of one row to the start of the next; release focuses the selected window.
- [ ] On the ultrawide, hold Cmd-Tab with your usual windows. Say here if the row count or the Tile sizes look wrong: the widest display tried was 1920 by 1080, where eleven cards fit one row.
- [ ] On a real keyboard, in a strip of two rows, keep Command down and press Down, then Up. The selection moves to the Tile below and back.

**Release a dogfood build on every land**
- [ ] `brew upgrade --cask winmux` on the daily machine keeps the Accessibility and Screen Recording grants. It did in a guest with SIP off, by `brew upgrade` and by Sparkle.
- [ ] After that upgrade WinMux does not ask to "bypass the system private window picker". It asked once in a guest, on one version of three.

## From the first build

- [ ] The double-sided flip animates (deployment target).
- [ ] The Settings panes show the loaded config, and sidebar renames survive a restart (Nickel config).
- [ ] A signed build shows the screen-recording indicator as expected while a Lens with pictures is open (thumbnail cache).
- [ ] The strip and the Cmd-Tab takeover survive a real sleep, wake and unlock, and fast user switching (strip).
- [ ] A window moves between two real displays, and a display changes size, with Columns on (fixed Columns, Column Policy hooks).
