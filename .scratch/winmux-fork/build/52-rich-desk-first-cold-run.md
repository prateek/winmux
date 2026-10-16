# The fourteen-window desk stages on its first run in a fresh guest

Part of {{UMBRELLA}}.

## What to build

`.claude/skills/demo/desk/stage-rich.sh` stages the desk every Lens issue films. In a fresh clone of the golden image its first run exits 1 with "no Safari window titled Lenses", and its second run passes. Three more things follow it around, and each driver hands them to the next by hand:

- The second run leaves one extra plain Ghostty terminal, which the driver closes through the guest CLI.
- A fresh guest's Notes sometimes stays on its empty screen until `open -a Notes`, a wait and a restaging.
- Column placement occasionally reports an error on the first pass.

No first-run screen is involved; **A fresh guest stages the desk with no first-run screens** left the script's waits alone.

## Decisions

- **One run, exit 0, fourteen windows**, in a guest that has never run the script.
- **Wait for a condition, not a time.** Where the script sleeps and then looks for a window, it polls for the window with a bound, and fails with the name of the window it waited for.
- **No extra window.** The script ends with exactly the windows the set lists; a window it did not open is a failure, not something to close afterwards.
- **The app set and the layout do not change.**

## Depends on

Nothing.

## Defaults chosen for you

- **The cause.** Safari's first launch in a clone is slower than the five seconds the script allows before it opens the second page. Check that before changing anything else.

## Built

The cold reproduction confirmed **The cause**: Cmd-N reached Ghostty before Safari became frontmost, and the next URL replaced the Lenses page. The second unchanged run also sent Cmd-N to Ghostty and reported Column errors despite exiting 0.

The script now sets Safari’s sandboxed `TabCreationPolicy` to open external URLs in windows. It sends no window-creation keystrokes and closes no extra windows. One polling function bounds process shutdown, CLI readiness, native activation and Focus, named windows, the local Notes list and its matching window title, the docs server, workspaces and Column membership. Each condition has 60 seconds by default, overridable with `STAGE_RICH_TIMEOUT`; the poll interval is 0.25 seconds. `WINMUX_CLI` selects the CLI, defaulting to the guest debug build, so plain-Python tests can use a stub. Final validation compares the fourteen app/title entries including duplicate titles, and names every missing or extra window. Notes’ exact expected title follows its existing local note count; the script changes no note content.

The rich set requires at least 1920×1080 points before it stops any apps. Its bootstrap config disables automatic reload while the original rich config is restored and explicitly loaded, then waits for the three/two Columns. The rich config and the standing set are unchanged. Host and pinned-version guest `make check` pass (1,257 Swift, 82 helper and 125 Python tests). Three consecutive fresh clones each stage fourteen windows on their first run, with the original workspace, Column, tab-group and floating layout checked by CLI readback and screenshots. A live unavailable-Calculator run fails by name after its 60-second wait; plain-Python tests cover delayed appearance and bounded absence through the same CLI seam.

## Done when

- [x] In three fresh clones in a row, the first run of `stage-rich.sh` exits 0 with fourteen windows and no other.
- [x] A missing window fails the run with its name within the bound.
- [x] The `demo` skill and the handoff no longer tell a driver to run it twice, restage Notes or close a terminal.

## Sources

- The handoff's status line for the first-run screens issue, and pull requests [#79](https://github.com/prateek/winmux/pull/79) and [#80](https://github.com/prateek/winmux/pull/80).
