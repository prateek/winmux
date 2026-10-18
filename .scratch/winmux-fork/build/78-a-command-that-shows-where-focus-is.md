# A command that shows where focus is

Part of {{UMBRELLA}}.

## What to build

WinMux draws nothing on the focused window. On a wide display with several Columns, Prateek could not tell where focus was.

A command shows the focused window for a moment.

## Decisions

- **A command, bound by a person to a key**, not a permanent border. Prateek: "a find focus trigger which will make it visually easy to identify where focus is … only needs to be temporary."

## Not in this issue

- A focus border or dimming that stays on.
- Moving the pointer to the focused window.

## Depends on

Nothing.

## Defaults chosen for you

- **The look**: a border on the focused window and every other window dimmed, for about a second, fading out. Show it in the pull request so he can say if it is wrong.
- **The command's name** is `find-focus`.
- **No default chord.** It gets a letter in the windowing mode.
- **Any key or click ends it early.**

## Done when

- [x] `winmux find-focus` marks the focused window on the staged desk and clears within two seconds.
- [x] It marks the right window when the focused one is in a tab group and when it floats.
- [ ] The pull request has a clip.

## Built

`find-focus` takes no arguments, is allowed in config and command URLs, and prints nothing on success. The window mode's `c` runs it without leaving that mode; main gains no chord. Every display is dimmed black at 0.35 opacity except the focused window's live frame, with an inside 4-point accent border and 10-point rounded corners. Tab-group chrome is outside the mark. Missing AX geometry falls back to the cached actual frame, then applied layout geometry; no usable frame fails explicitly. Empty focus fails with `find-focus: no window is focused`. Mission Control open draws nothing and succeeds; a disabled WinMux refuses it through the socket as it refuses every other command, and runs no session for it.

The mark holds for 0.8 seconds and fades for 0.4 seconds. Repeating it resets full opacity and timing. Key or mouse button down, a binding, changed window/workspace focus, changed applied layout, disable, ordinary config reload and Mission Control end it immediately. Modifier-only input and unchanged refreshes keep it. Dry-run reloads do not dismiss it.

Host and pinned-version guest `make check` pass: 1,575 Swift tests, including 27 behavior tests for this command, 92 Rust tests and 171 Python tests. The guest skips the existing committed-hash test because its sync marker represents the host's working copy. Default binding removal also passes the helper's `check` command. Mutations of target geometry, border width, timing, input and dismissal hooks fail the regressions; restoring them passes.

Standing-desk recordings show tiling, the active tab after `focus tab-next`, floating and fullscreen; the active app and window are unchanged by the mark. Captures also cover key/click/focus/layout/disable/reload dismissal, modifier-only input, both restart phases, App Exposé suppression, and empty-workspace stderr/exit 1. Synthetic Option-semicolon then `c` reaches Carbon and retains `window` mode. The same feature-off script has identical output on the base and feature trees. Proof tools are in `.scratch/winmux-fork/proofs/find-focus/`; final-commit pull request media belongs to the demo pass.

No default chosen for this issue changed.

## Checks needing the installed build or hardware

- [ ] Installed-build behavior, including a real keyboard.
- [ ] A second display, including a window spanning displays.
- [ ] Real sleep, wake and unlock.

## Sources

- Prateek, 2026-10-07: "how do i tell where focus/cursor is".
