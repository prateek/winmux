# A windowing mode on `alt-semicolon`

Part of {{UMBRELLA}}.

## What to build

`alt-semicolon` enters the `lens` binding mode today: four letters that open Lenses, and Escape. **A short list of default shortcuts** leaves most window commands without a chord. Prateek asked for a windowing mode, where plain keys drive windows, and chose to make this one mode.

`alt-semicolon` enters a mode in which plain keys move focus, move windows, switch workspaces and open Lenses, until Escape.

## Decisions

- **One mode, on `alt-semicolon`.** It replaces the `lens` mode and keeps its letters.
- **It stays until Escape.** A command that moves focus or a window leaves the mode on. A letter that opens a Lens leaves the mode, as today.
- **Plain keys, vim's where vim has one**: `h` `j` `k` `l` focus, with shift they move the window, digits go to a workspace, with shift they send the window.

## Not in this issue

- A tap of Caps Lock or Escape to enter the mode. Prateek dropped the key and kept the mode.
- Resize, which upstream keeps in a mode of its own; say in the pull request if it fits here.

## Depends on

- **A short list of default shortcuts**.

## Defaults chosen for you

- **The mode is visible while it is on**: a small HUD naming the mode, or the menu-bar item. A mode a person cannot see is a keyboard that has stopped working.
- **The rest of the letters**: next and previous tab, the join directions, float or tile, fullscreen, project next and previous. Pick mnemonics and list them in `docs/default-config.md`.
- **The mode's name** in config stays `lens` if renaming breaks imports; otherwise `window`.

## Done when

- [ ] On the defaults, `alt-semicolon` then `l` `l` `shift-j` `3` moves focus twice, moves the window and goes to workspace 3, with the mode still on; Escape leaves it.
- [ ] `alt-semicolon` then `o` opens `overview` and the mode is off.
- [ ] Something on screen shows the mode is on.
- [ ] The docs list every key of the mode.

## Sources

- Prateek, 2026-10-07: "esc-key as a shortcut to go into windowing mode?", then "drop the keybind, focus on the mode".
- Prateek, 2026-10-13: one mode on `alt-semicolon`.
