# Grilling: fixed Columns, Width presets and Overflow policy semantics

Type: grilling
Status: resolved
Blocked by: 04

## Question

Pin down the Column model: how a Column count is declared per Display profile, how new windows fill Columns (next empty? next to focus?), what Width presets exist and how cycling works (per Column, what the neighbours do), the configurable Overflow policy options and the tab-group default, what happens when windows close (Columns collapse or hold their slot), and how this interacts with manual splits, resize, balance, and tab groups.

Sub-questions surfaced by the layout-engine research:
- With fewer windows than Columns: fill the width, or keep presets and leave blank space (needs a placeholder node or root padding)?
- Which Column takes overflow: focused, MRU, or last?
- Does the Column count constrain `move`, `move-node-to-workspace` and drag-and-drop, or only new windows?
- Presets that don't sum to 1: who shrinks?
- What `balance-sizes` means in Columns mode.
- Preset cycling needs a new command or `resize` mode.
- Naming: WinMux's `stack-with` makes a tab group, so an Overflow option called "stack" will mislead. Pick distinct names (e.g. `tab-group`, `split-vertical`, `squeeze`, `float`).

## Answer

> Amended (2026-09-30): [Prototype: grid Presentation look and behaviour](08-prototype-grid-presentation.md) decided that `summon` counts as a tiling window arriving on the current workspace, so `place` picks its Column. `arrive` doesn't run for it.

> Amended (2026-09-29): [Prototype: config and scripting language](27-prototype-config-language.md) chose Nickel, merged `[[on-window-detected]]` and `place` into one `arrive` hook, and let hook results add an optional `run` list of commands after the fixed placement action.

Grilled with Prateek on 2026-09-29.

- **Slot model, not viewports.** A Column is a marked child of the workspace's `h` root, and switching workspace changes every Column at once. The viewport model from `codex-columns` (each Column pages its own deck of workspaces) is rejected for this fork. Lenses and Summon cover "bring Slack here".
- **Positional Columns.** Each Column keeps its x-range and Width preset when it's empty. With one window on a three-Column ultrawide, that window sits in its Column and the other Columns show the desktop. Closing a window leaves its Column empty, and a `compact` command packs windows on demand. Layout needs a slot index per root child, because the tree can't hold empty containers.
- **Any arrangement inside a Column.** One window, a tab group, or splits in either direction, side by side included. Normalization (flatten and opposite orientation) leaves Column nodes alone and still applies inside them.
- **The Column count is an invariant on every path**: new window, `move`, `move-node-to-workspace`, drag and drop, cache restore, flatten. A pass after normalization enforces it. `squeeze` is the only way to exceed the count.
- **Policy hooks, language-agnostic.** At fixed decision points WinMux asks the config, gives it the window, the Filter context and the workspace's Columns (index, empty, windows, width), and gets back one action from a fixed vocabulary. The vocabulary stays fixed, not arbitrary command lists, so it can be checked and explained. The syntax waits on [Prototype: config and scripting language](27-prototype-config-language.md).
  - `place` runs when a tiling window arrives on the workspace, after on-window-detected callbacks. It returns a target Column (`<n>`, `focused`, `mru`, `nearest-empty`, `last`) and an **Overflow policy** action used if that Column is occupied: `tab-group`, `split`, `float` or `squeeze`. None is called "stack", because `stack-with` already means tab group. Default: `nearest-empty`, else `tab-group` into the focused Column, falling back to the MRU Column when focus isn't on this workspace's tiling tree.
  - `move-boundary` runs when `move left/right` crosses a Column edge. Into an occupied Column it returns `join` (with an Overflow action) or `swap`. At the workspace edge it returns `stop`, `wrap`, `next-workspace` or `next-monitor`. Default: `join` using `place`'s Overflow action, and `stop` at the edge. An empty neighbour just takes the window.
  - Closing a window has no hook.
  - AeroSpace's `[[on-window-detected]]` stays separate for now, and it remains the place for arbitrary commands. Merging the two is in scope for the language prototype.
- **Widths.** A profile declares the starting `widths` (fractions) and a global `width-presets` list. `column-width next|prev|<fraction>` cycles the focused Column, and its neighbours give up or take space in proportion to their widths, so the total stays 1. Free `resize` and divider drag are allowed, with a minimum Column width, and presets are just stops. `resize` on a window alone in its Column resizes the Column; inside a split it resizes within the Column. Widths are per-workspace state stored as fractions, re-applied before layout, and reset when the Display profile changes. `balance-sizes` resets to the declared `widths` and balances inside each Column. Declared widths that don't sum to 1 are normalized proportionally, with a warning when the config loads.
- **Focus.** `focus left/right` skip empty Columns. `focus-column <n>` can focus an empty Column, which gets a faint outline, so the next window's `focused` target lands there.
- **Config shape and precedence.** `[columns]`, then `[columns.when.<profile>]`, then `[workspace.<name>.columns]`, then `[workspace.<name>.columns.when.<profile>]`, with the most specific winning field by field and hook definitions replaced rather than merged. `count = 'off'` (the laptop default) means plain tree tiling. A Display profile is now a named condition that settings key on, not a bundle of settings. Profile matching stays with [Grilling: Display profile contents and switch behaviour](10-grilling-display-profiles.md).
- **CLI**, subject to naming by [Grilling: CLI surface for the fork's features](20-grilling-cli-surface.md): `focus-column <n>`, `move-node-to-column <n>`, `column-width next|prev|<fraction>`, `compact`, `list-columns [--json]` (index, width, empty, window ids, resolved profile), and `columns place --dry-run --window <id>`, which explains which hook result a window would get. `move`, `resize` and `balance-sizes` keep their names with the behaviour above.
