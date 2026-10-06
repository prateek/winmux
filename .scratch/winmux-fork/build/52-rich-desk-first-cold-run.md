# The fourteen-window desk stages on its first run in a fresh guest

Part of {{UMBRELLA}}.

## What to build

`demo/desk/stage-rich.sh` stages the desk every Lens issue films. In a fresh clone of the golden image its first run exits 1 with "no Safari window titled Lenses", and its second run passes. Three more things follow it around, and each driver hands them to the next by hand:

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

## Done when

- [ ] In three fresh clones in a row, the first run of `stage-rich.sh` exits 0 with fourteen windows and no other.
- [ ] A missing window fails the run with its name within the bound.
- [ ] The `demo` skill and the handoff no longer tell a driver to run it twice, restage Notes or close a terminal.

## Sources

- The handoff's status line for the first-run screens issue, and pull requests [#79](https://github.com/prateek/winmux/pull/79) and [#80](https://github.com/prateek/winmux/pull/80).
