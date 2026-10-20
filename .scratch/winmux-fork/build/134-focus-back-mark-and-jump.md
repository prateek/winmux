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

- [x] Tests cover `focus-back` across workspaces and projects, a mark surviving a workspace move, a mark cleared by its window closing, and `jump` to an empty register exiting 1.
- [x] In a guest, `mark a`, focus elsewhere, `jump a` returns, and `focus-back` toggles between two windows on different workspaces.
- [x] `docs/cli.md` lists the four commands.

## Built and checked

- `focus-back` uses the confirmed-focus history the Filter context's `previous` uses, and agrees with it except in one case: when macOS has focused a window in native fullscreen, which `focus` never points at, the Filter's `previous` is that window itself, and `focus-back` takes the window before it. It exits 1 with `No previously focused window` when none exists. It never falls back to a never-focused window or an empty workspace. `focus-back-and-forth` keeps its existing behavior. The return-trip test confirms the first request as a refresh would before requesting the second.
- The Lens `focus` verb, `focus-back` and `jump` share `focusLensWindow`: restore at the retained origin, request logical focus except for popups, then request native focus. **A minimized or hidden-app window** keeps the Default's requested restoration behavior, but restoration comes from the Lens path, not from `focus --window-id`, which remains unchanged. The Default's attribution to `focus` was incorrect; no Default behavior changed.
- One in-memory register-to-window-id map survives replacement of Window objects. Registration prunes it and the focus history in one call, `Window.forgetWindows(except:)`, with the live-plus-closed-cache set. All readers omit unavailable windows without erasing a temporarily absent id that the cache may restore. Restart clears the map.
- Registers accept exactly one lowercase ASCII letter. Reassignment moves only that register; multiple registers can name one window. Bare `mark` prints sorted letters separated by spaces, with no output for no marks. `mark` acts on the window a Lens action or a hook names, and otherwise on the window the person is in, a native-fullscreen one included. Both mark forms exit 1 with `No window is focused` when there is none. Invalid arguments follow the CLI's existing parse-error exit code, 1.
- `list-marks` reuses `list-windows` padding and JSON encoding, adding `register` to `window-id`, `app-name` and `window-title`. There is no `--format`. The URL gate refuses bare `mark` and `list-marks`, and permits register assignment, `jump` and `focus-back`.
- Nineteen command tests cover the required cases, restoration, popup focus, native fullscreen, the window a command runs for, a binding that moves focus and then marks, replacement and cache retention, parsing, both output forms and URL policy. The existing minimized Lens focus test also checks native focus. The new tests were seen failing before each fix. `make check` passes on the host and in the guest on CI's pinned Swift.
- Standing-desk screenshots, command transcripts with exit codes, window lists and agent trees check `mark a`, a cross-workspace `jump a`, four alternating `focus-back` calls, both list forms, empty-register failure, minimized restoration and closed-register omission. Additional captures check a workspace move, hidden-app restoration, register reassignment, already-focused success, parse errors, and clearing marks plus the previous-window error after restart. Source-workspace screenshots agree with the window lists and trees. No permission was granted. Proof scripts are in `.scratch/winmux-fork/proofs/window-marks/`; builder captures remain in the relay artifacts, separate from final-commit demos.
- No default binding, Lens guide, cask shape or on-disk state format changes. After a Sparkle app update, the installed CLI needs `brew upgrade --cask --greedy winmux` to learn the new commands.

## Checks for Prateek

- [ ] After `brew upgrade --cask --greedy winmux` (Sparkle does not update the cask's `winmux`), run `winmux mark a` on a window, switch to another workspace and focus a window there, then run `winmux jump a`, then `winmux focus-back`. Pass: `jump a` shows the marked window on its own workspace, and `focus-back` returns to the window you jumped from.
- [ ] With two displays, run `winmux mark a` on a window on one display, focus a window on the other, then run `winmux jump a`. Pass: focus lands on the marked window, and the other display keeps the workspace it showed.
- [ ] Run `winmux mark a` on a window, lock the screen and unlock it, then run `winmux jump a`. Pass: it focuses the window you marked, and `winmux list-marks` still lists it.

## Sources

- The grilling record, 2026-10-19, "The keyboard".
- #268, "Vim-style focus: toggle between the last two windows, and marks".
