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

- [ ] `winmux find-focus` marks the focused window on the staged desk and clears within two seconds.
- [ ] It marks the right window when the focused one is in a tab group and when it floats.
- [ ] The pull request has a clip.

## Sources

- Prateek, 2026-10-07: "how do i tell where focus/cursor is".
