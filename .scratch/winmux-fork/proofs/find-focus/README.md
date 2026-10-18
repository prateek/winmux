# Find-focus proof tools

Run debug builds only in the assigned guest, through the VM skill's wrappers.
Set the driver's `TART_HOME` in each host shell. Sync, build and run `vm check`
before recording; `vm check` quits the debug manager.

Push this directory to `~/focus-proof` and the demo desk to `~/desk` with
`vm push`. Compile these tools through `vm ssh`:

```sh
swiftc ~/focus-proof/observe.swift -o ~/focus-proof/observe
swiftc ~/winmux/.claude/skills/demo/keys.swift -o ~/desk/keys
swiftc ~/winmux/.scratch/winmux-fork/proofs/sidebar-shortcuts/arrow-chord.swift -o ~/focus-proof/arrow-chord
```

Stage the standing desk. If staging finds Python's Local Network prompt,
capture it, dismiss it with `killall UserNotificationCenter` without answering,
and check the desk again before filming. A permission prompt for WinMux or the
recorder stops the run. Never answer one.

Restart the debug manager with the desk's config copied to
`~/demo/find-focus-config/winmux/winmux.ncl`, `XDG_CONFIG_HOME` set to
`~/demo/find-focus-config`, `XDG_STATE_HOME` to `~/demo/state`, and
`WINMUX_NICKEL_HELPER` to the synced tree's release helper. Wait fifteen seconds
before reading its inventory. Then, through `vm ssh`:

```sh
export FIND_FOCUS_CAPTURES=$HOME/takes/find-focus/final
zsh ~/focus-proof/live.zsh
zsh ~/focus-proof/extra.zsh
zsh ~/focus-proof/late.zsh
```

Choose an empty output directory: `screencapture` refuses to overwrite a movie.
The scripts save before/after logical and native focus, movies, mark/action/end
screenshots, command output and WindowServer alpha samples. `live.zsh` covers
tiling, key/click/focus/disable/reload dismissal, modifiers, restart, tabs,
floating, fullscreen, empty focus and the real synthetic window-mode chord.
`extra.zsh` switches tabs explicitly and checks applied-layout dismissal;
`late.zsh` checks a restart during fading and App Exposé suppression.
Run `close.zsh` last to mark and close the floating terminal, then verify focus
returns to the remaining editor and the old mark is gone.

Pull the takes with `vm pull`. Extract and inspect a marked frame from every
movie. `inspect-movies.py <directory>` selects a frame with a blue accent border
from each movie in the default-blue guest and writes its timestamp and still.
Inspect those stills: the pixel count alone does not establish the right target.
For a tiled take with Zed on the right, run the host timing tool:

```sh
python3 .scratch/winmux-fork/proofs/find-focus/frame-timing.py tiled.mov
```

It samples the right-hand window's inside border at `(670, 300)`. For Zed on
the left, pass `64 300` after the movie. Check that the chosen pixel is on the
inside border in the recorded layout. The frame timestamps are the recording's, while the CSV
samples have their own start. Controlled-clock tests establish exact deadlines.
An early dismissal must go from alpha 1 to absent without intermediate alpha
samples. The panel disables AppKit's automatic ordering animation; its explicit
timed fade still has intermediate values. Variable-frame-rate movies can omit
part of the hold or fade, so retain those gaps when reporting timing bounds.

For preserved behavior, push the base commit's tree to a second guest directory,
initialize its `.git` directory, and build it over `vm ssh`. Copy its fetched
Sparkle framework beside its executable. Run `unchanged.zsh <tree> <label>`
against both trees and compare `<label>.unchanged.txt`. The same script exercises
binding dispatch, focus, mode, layout, fullscreen, disable/re-enable and inventory
without ever invoking the feature. It quits each manager after its run.

Close the staged apps and stop the desk's docs server after recording. Leave the
assigned guest running. Installed-build, physical keyboard, second-display and
real sleep/wake/unlock checks remain separate.
