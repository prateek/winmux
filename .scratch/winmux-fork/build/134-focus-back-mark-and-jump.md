# focus-back, mark and jump

Part of {{UMBRELLA}}.

## What to build

Vim's two cheapest moves have no WinMux command: going back to the window you were just in, and jumping to a window you named. Prateek asked for both, with a mode so bare letters never collide with an app's vim bindings; the mode exists, `window`, and **The shipped keyboard: a minimal main and a full window mode** binds the keys. This issue builds the commands.

## Decisions

- **`focus-back`** focuses the previously focused window, wherever it is, switching workspace and project as `focus --window-id` does. A second `focus-back` returns. It uses the Filter context's previously focused window, so the two agree.
- **`mark <register>`** names the focused window with one letter, `a` to `z`. A register holds one window; marking again moves it. A window keeps its marks until it closes.
- **`jump <register>`** focuses the marked window as `focus-back` would, and exits 1 with a message naming the register when it is empty or its window is gone.
- **`list-marks`** prints register, window id, app and title, and `--json`.
- **Marks are per WinMux process**, not saved; a restart clears them.
- **A Lens mark is a different thing** and keeps its name in the Lens docs; these are window marks, and the docs say so once.

## Not in this issue

- The `window` mode keys: **The shipped keyboard: a minimal main and a full window mode**.

## Depends on

Nothing.

## Defaults chosen for you

- **A minimized or hidden-app window** is restored by `jump`, as `focus` does today.
- **`mark` with no register** prints the registers the focused window holds.

## Done when

- [ ] Tests cover `focus-back` across workspaces and projects, a mark surviving a workspace move, a mark cleared by its window closing, and `jump` to an empty register exiting 1.
- [ ] In a guest, `mark a`, focus elsewhere, `jump a` returns, and `focus-back` toggles between two windows on different workspaces.
- [ ] `docs/cli.md` lists the four commands.

## Sources

- The grilling record, 2026-10-19, "The keyboard".
- #268, "Vim-style focus: toggle between the last two windows, and marks".
