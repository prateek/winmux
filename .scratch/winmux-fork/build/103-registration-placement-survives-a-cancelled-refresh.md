# A window registered or restored during a cancelled refresh misses its placement hook

Part of {{UMBRELLA}}.

## What to build

**`arrive` is skipped when its refresh session is cancelled** shields the `arrive` call itself. Two neighbouring paths in the same registration still lose their hook when a hotkey cancels the refresh that detected the window:

- **Closed-window-cache and frozen-world restores.** `MacWindow.getOrRegister` calls `restoreClosedWindowsCacheIfNeeded` and `restorePersistedFrozenWorldIfNeeded` before `arrive`. A restored tiling window on a workspace with Columns and a `place` hook goes through `relayoutWindow` and `ColumnPolicy.place`. A hotkey pressed while that `place` call gathers its arguments cancels it: `ColumnPolicy.call` swallows the `CancellationError`, and the restored window gets the built-in Column with nothing recorded.
- **The gap before `arrive`.** The window is in `MacWindow.allWindowsMap` before `debugWindowsIfRecording` and the two restores run. A cancellation that surfaces in one of those awaits ends registration there. The next refresh finds the window already registered and returns it at once, so `arrive` never runs for it.

Both are found by reading the code; neither has been reproduced live. The second needs one of three awaits that rarely suspend to suspend at the wrong moment.

## Decisions

- A window registered by a refresh gets its placement once, by `arrive` or by restoration, whether or not that refresh is cancelled.
- A frozen-world restore does not run in a shield of its own: it binds several windows and sets active workspaces, and it would race the command that cancelled it.

## Not in this issue

- `place` and `move-boundary` calls made for a hotkey or CLI command. They follow that command's cancellation.

## Depends on

**`arrive` is skipped when its refresh session is cancelled**.

## Done when

- [ ] A test cancels the refresh while a restored window's `place` call gathers its arguments, and the window ends in the Column the hook names.
- [ ] A test cancels registration before `arrive` starts, and the next refresh runs `arrive` for the window exactly once.
- [ ] Each test fails without the change.

## Sources

- Finding 7 of the review of the pull request for **`arrive` is skipped when its refresh session is cancelled**.
