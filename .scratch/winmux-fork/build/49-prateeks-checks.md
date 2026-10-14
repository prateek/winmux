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

**Mission Control and Exposé with WinMux running**
- [ ] With WinMux running and windows on three or more workspaces, swipe up on the ultrawide. Say here whether the thumbnails are tiny and scattered, and whether the slowness is in the animation or in finding the window. A guest showed thumbnails at about 8% of real size and no extra delay, opened by key.
- [ ] In System Settings, Trackpad, More Gestures, open the Mission Control menu and say here whether it offers "Off". A WinMux view on that swipe needs the system's gesture turned off first.
- [ ] In Mission Control, press an arrow key, then Return. Say here whether a window was selected and focused. Sources disagree.

**The system's Cmd-Tab stays the system's, and a short list of default shortcuts**
- [ ] After the build with this change arrives on the daily machine, by Sparkle or `brew upgrade --cask winmux`, run `winmux config check`. If it says a chord "is no longer a default binding", delete that removal from your config, or use `W.without-bindings`, and check again. A pass prints nothing, and `winmux doctor` then names your own config file.
- [ ] With your config and no `cmd-tab` binding in it, hold Cmd-Tab. It is Apple's app switcher, and `winmux doctor` shows `held=[] marker=[]`.
- [ ] On a real keyboard, `ctrl-w` deletes a word and `ctrl-r` searches history in your shell, and `alt-shift-o` opens `overview`.

**Display profiles: match a profile to the attached display**
- [ ] Once it has landed: with a profile for the laptop panel and one for the ultrawide, undock and dock with the lid shut, then with it open, then run your display script. Each time the Column count changes once, after the display settles, and docking again restores the ultrawide's arrangement.

**Release a dogfood build on every land**
- [ ] `brew upgrade --cask winmux` on the daily machine keeps the Accessibility and Screen Recording grants. It did in a guest with SIP off, by `brew upgrade` and by Sparkle.
- [ ] After that upgrade WinMux does not ask to "bypass the system private window picker". It asked once in a guest, on one version of three.

**A windowing mode on `alt-semicolon`**
- [ ] On a real keyboard, press `alt-semicolon`, let go, then `l`, `l`, `shift-j`, `3`, Escape. Focus moves twice, the window moves down, workspace 3 comes up, and a small `window` label sits at the bottom centre of the screen until Escape. Then do it fast, as you would in use: say here if the first letter after `alt-semicolon` is typed into the app as `¬` or another Option character, which means Option was still down when it landed.
- [ ] With a second display attached and the mode on, move focus to a window on the other display. The `window` label follows to that display.
- [ ] After the build with this change arrives, run `winmux config check`. If it says "The default binding mode lens was renamed to window", change that read to `defaults.mode.window.binding`. A config converted earlier keeps its own five-letter `lens` mode until you replace it.

**The Hold ends at the first letter**
- [ ] With the Cmd-Tab opt-in, on a real keyboard: Cmd-Tab, then `j` with Command still down, release, wait a second, `j`, Return. The strip stays up after the release, each `j` moves the selection, and Return focuses the selected window. Then press `j` as fast after Cmd-Tab as you can: say here if the `j` goes to the app in front instead (anything within about 100 ms of the Tab does, before the strip is drawn).
- [ ] `alt-slash`, then type "safari" at your normal speed. Search reads `safari`. Say here if it reads `sßfari`, `føø`-style, or loses the first letter: that means Option was still down after the first letter, which now types an Option character.
- [ ] `alt-shift-o`, then `j` with both still down, release. The overview stays open with its selection moved, and Return focuses that window.
- [ ] Tap Cmd-Tab and let go as fast as you can, five times. Each time it switches to the previous window, and no strip is left on screen.

## From the first build

- [ ] The double-sided flip animates (deployment target).
- [ ] The Settings panes show the loaded config, and sidebar renames survive a restart (Nickel config).
- [ ] A signed build shows the screen-recording indicator as expected while a Lens with pictures is open (thumbnail cache).
- [ ] The strip and the Cmd-Tab takeover survive a real sleep, wake and unlock, and fast user switching (strip).
- [ ] A window moves between two real displays, and a display changes size, with Columns on (fixed Columns, Column Policy hooks).
