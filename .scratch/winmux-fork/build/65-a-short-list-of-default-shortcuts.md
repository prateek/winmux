# A short list of default shortcuts

Part of {{UMBRELLA}}.

## What to build

Before this change, WinMux shipped 95 default bindings in `main`, and its event tap took each one in every app. An audit on 2026-10-07 found that twelve take a shortcut people use all day and 43 take a lesser one. The worst are the eight bare-Control letters: `ctrl-w`, `ctrl-e`, `ctrl-r`, `ctrl-t`, `ctrl-h`, `ctrl-l`, `ctrl-q` and `ctrl-f` are delete-word, end-of-line, history search, backspace and clear-screen in every shell, editor and text field. Prateek removed all eight in his own config after a day of use.

The defaults shrink to a list small enough to learn and to check for collisions. Everything removed stays a command a config can bind.

## Decisions

- **The defaults in `main` bind these and nothing else.**

  | Purpose | Chords | Count |
  | --- | --- | --- |
  | Focus a neighbour | `alt-h`, `alt-j`, `alt-k`, `alt-l` | 4 |
  | Move the window | `alt-shift-h`, `alt-shift-j`, `alt-shift-k`, `alt-shift-l` | 4 |
  | Go to a workspace | `ctrl-1` to `ctrl-9` | 9 |
  | Send the window to a workspace | `alt-shift-1` to `alt-shift-9` | 9 |
  | Float or tile, fullscreen | `alt-shift-t`, `alt-shift-m` | 2 |
  | Search windows | `alt-slash` | 1 |
  | Open the overview | `alt-shift-o` | 1 |
  | Focus a tab by index | `alt-1` to `alt-9`, `alt-0` | 10 |
  | The binding mode for everything else | `alt-semicolon` | 1 |

- **`alt-tab` and `alt-shift-tab` are not bound.** Prateek: "dont bind alt-tab". Other switchers expect that chord to be free.
- **Unbound by default**: the eight bare-Control letters, `ctrl-0`, the `cmd-ctrl-` and `ctrl-shift-` workspace duplicates, every project chord, the `cmd-shift-` join chords, stack, swap, `balance-sizes` and `alt-space`.
- **`cmd-tab`, `cmd-shift-tab` and `cmd-backtick`** are covered by **The system's Cmd-Tab stays the system's unless the config asks for it**. The two issues change the same defaults and can land as one pull request.

## Not in this issue

- Removing a command. Only its default chord goes.
- The keys inside an open Lens and the letters of the `lens` binding mode.
- A Settings pane for shortcuts.
- Freeing a chord with an empty command list. That is **A chord bound to an empty command list is still taken**.

## Depends on

Nothing.

## Defaults chosen for you

- **The ten tab digits stay unchanged**: `alt-1` to `alt-9` and `alt-0` target indices 1 through 10. **The ninth tab digit goes to the last tab** is separate work.
- **The overview chord is `alt-shift-o`.** The `alt-shift-` family had no collision in the audit beyond two currency symbols. It types `Ø` on US and ABC. It has no system symbolic-hotkey collision and stays as chosen. Its held modifiers overlap Enter's Summon bindings; the upgrade guide describes the routing, which belongs to **The Hold ends at the first letter**.
- **What lost its chord is reached in the mode on `alt-semicolon`**, which **A windowing mode on `alt-semicolon`** builds. Until it lands, the removed chords are documented as lines to paste.
- **An existing config that imports the defaults** loses the removed chords on upgrade. The release notes and `docs/default-config.md` carry the old block, ready to paste.
- **`config convert`** output is unchanged for a converted TOML's own bindings.

## Done when

- [x] With no config, the loaded bindings are the chords above, the tab digits and the Lens keys, and nothing else.
- [x] `ctrl-w`, `ctrl-r`, `ctrl-l` and `cmd-shift-k` reach the focused app with WinMux running on the defaults, checked in a guest.
- [x] `docs/default-config.md` lists the defaults, and the removed block as lines to paste.
- [x] The helper's default-config tests are updated, not deleted.

## Built

Built together with **The system's Cmd-Tab stays the system's unless the config asks for it**. Main has exactly 41 chords, protected by set-equality tests in both the helper and Swift. The Lens leader keeps `o`, `f`, `s`, `r`, Escape and gains only `a` for the same-app list; no windowing mode was added. Removed bindings are ready to paste in the upgrading section of `docs/default-config.md`.

The guest's loaded no-config JSON has the exact set. Ghostty accessible text proves Ctrl-W word deletion, Ctrl-R history search and Ctrl-L clearing; Zed's Cmd-Shift-K deletes a line, with clipboard text read back. Alt-L, Alt-Shift-L, Ctrl-2, Alt-Shift-3, Search, direct overview and leader `a/r/o` each have screenshots and runtime readbacks. Both demo desks explicitly opt in to switching; their scripts stage with the new defaults. Conversion preserves all upstream fixture commands and a custom Cmd-Tab binding. Host and guest `make check` pass, with no skipped Swift tests.

Option-Shift-O remains the overview Trigger. It types `Ø` on US and ABC; Enter Summons with Option, Shift or both still down. Summon hints subtract an active Hold in every Presentation, while Lens-key routing remains unchanged for **The Hold ends at the first letter**. The library's `W.without-bindings` ignores absent chords; missing-field errors for the removed defaults explain that their old removal can be deleted. The upgrade guide also covers earlier conversions' explicit Cmd bindings and the redeclaration error for an alternative spelling of the new defaults. No default chosen for this combined pass was changed.

## Checks for Prateek

- [ ] Installed dogfood build behavior.
- [ ] A second physical display.
- [ ] Real sleep, wake and unlock.

## Sources

- Prateek, 2026-10-07, after a day on his work machine: "audit default keybinds", with `ctrl-w` as the example.
- The audit of the defaults, 2026-10-07: 114 bindings counting Lens keys and the `lens` mode; 12 break, 43 shadow, 59 clear.
- Prateek, 2026-10-13: "i want to remove all of them but maybe thats too far, con you propose a minimal list", then, of the list above, "your suggestions are fine, dont bind alt-tab".
