# A windowing mode on `alt-semicolon`

Part of {{UMBRELLA}}.

## What to build

`alt-semicolon` enters the `window` binding mode: persistent window commands and five letters that leave it before opening Lenses. **A short list of default shortcuts** leaves most window commands without a chord. Prateek asked for a windowing mode, where plain keys drive windows, and chose to make this one mode.

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

- **The mode is visible while it is on**: a small non-activating HUD naming every non-main binding mode at the bottom centre of the focused monitor, alongside the existing menu-bar letter. A mode a person cannot see is a keyboard that has stopped working.
- **The rest of the letters**: next and previous tab, the join directions, float or tile, fullscreen, project next and previous. Use `n`/`p`, `ctrl-h/j/k/l`, `t`, `m`, and square brackets; the exact key map is in `docs/default-config.md`.
- **`alt-semicolon` inside the mode leaves it too**, as Escape does: Option-semicolon would otherwise type a character into the focused app. The relay added this.
- **The mode's name** in config is `window`, with no `lens` alias. User-defined `lens` modes remain valid; reads of `defaults.mode.lens.binding` fail with a migration hint.

## Done when

- [x] On the defaults, `alt-semicolon` then `l` `l` `shift-j` `3` moves focus twice, moves the window and goes to workspace 3, with the mode still on; Escape leaves it.
- [x] `alt-semicolon` then `o` opens `overview` and the mode is off.
- [x] Something on screen shows the mode is on.
- [x] The docs list every key of the mode.

## Build and validation

The defaults bind exactly 43 windowing keys; `main` keeps its 41 chords, changing only the Option-semicolon command. Every non-Lens command keeps the binding mode on, even when rejected. Only `o`, `f`, `s`, `r`, `a`, Escape and Option-semicolon leave it. Main chords are off inside it, and unbound keys reach the app.

The HUD shows only the active name. Mode changes, CLI entry, reload retention/removal and disabling update it; layout refresh follows monitor focus. It never becomes key and ignores clicks. The HUD is gone in overview's first recorded frame. The existing menu-bar letter is unchanged.

Conversion adds `window` keys only where that TOML mode has no binding for the chord; the three fork Triggers keep their existing addition rule. Earlier converted files retain their explicit `lens` mode and Trigger. Removed default reads receive a rename hint above Nickel's error. The docs keep the migration paste block and describe unknown-mode behavior.

Helper and Swift tests cover exact key sets, migration, conversion, the loaded-default binding sequence, failure persistence, HUD decisions, CLI entry, reload keep/drop and disable. Guest captures cover the Done-when sequence, all ruled key families, unbound text, inactive main chords, user modes and config examples. Resize remains outside this build; Ctrl-Shift-H/L and Ctrl-Shift-J/K would fit grow/shrink commands in a later change.

## Checks for Prateek

- [ ] Installed-build behavior.
- [ ] A real keyboard, including whether Option is released before the first plain letter after Option-semicolon.
- [ ] Focus following a second real display.
- [ ] Real sleep, wake and unlock.

## Sources

- Prateek, 2026-10-07: "esc-key as a shortcut to go into windowing mode?", then "drop the keybind, focus on the mode".
- Prateek, 2026-10-13: one mode on `alt-semicolon`.
