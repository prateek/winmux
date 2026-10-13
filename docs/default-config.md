# Default config and Triggers

With no config file, WinMux loads `winmux/defaults.ncl`. Columns are off, so new windows use ordinary tree tiling. Startup does not write a starter file unless it is converting a legacy config. “Open config” creates an editable import-only starter when needed.

A config imports defaults explicitly. This import-only config has the same static settings as a fresh install:

```nickel
let W = import "winmux/winmux.ncl" in
(import "winmux/defaults.ncl") | W.Config
```

Values in the default record can be overridden by merging an ordinary value over them:

```nickel
let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  mode.main.binding.alt-slash = "lens floating",
}) | W.Config
```

Remove a binding from the imported record before merging. The replacement binding record must take precedence over the original record, otherwise Nickel's merge would put the removed field back:

```nickel
let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in
let without-search = defaults & {
  mode.main.binding | force = std.record.remove "alt-slash" defaults.mode.main.binding,
} in
(without-search & { gaps.inner.horizontal = 4 }) | W.Config
```

Leaving the import out supplies no default Lenses or bindings. `winmux config convert` imports the five default Lenses. If the TOML has a `mode` table, conversion replaces the default modes with the TOML's modes and adds the fork's `lens` mode keys and three `main` Triggers, only where the TOML has no binding for those keys. Modifier order, keyboard presets and key aliases are resolved as in the Swift loader. Omitted upstream bindings stay omitted, and a user's `cmd-tab` command wins. Duplicate user spellings of the same chord fail conversion with a binding redeclaration diagnostic, and so does a `mode` table with no `main` mode. The converted modes are merged at normal priority, so a record merged over the converted file later can still add or change a binding. With no `mode` table, conversion keeps all default modes and bindings. A comment in the converted file describes the retained defaults and how to remove them.

`config-version` is optional, accepted and ignored for compatibility with earlier Nickel conversions, like `contract-version`. It is absent from shipped defaults and new conversions; both version keys are removed before the Swift settings parser runs. Nickel uses an explicit `persistent-workspaces` list, defaulting to empty. For TOML version 1 or lower, or an absent version, conversion preserves the old inferred persistence when the file sets no list: it writes workspace targets from every mode's `workspace` and `move-node-to-workspace` bindings, followed by force-assignment keys, in first-seen order, and prints a warning. A quoted name is one target. When nothing is inferred it writes no list and prints no warning. Relative `next` and `prev` targets declare no workspace. Version 2 and an explicit list suppress inference.

## The 41 default shortcuts

| Binding in `main` | Command |
| --- | --- |
| `alt-h/j/k/l` | `focus left/down/up/right` |
| `alt-shift-h/j/k/l` | `move left/down/up/right` |
| `ctrl-1` through `ctrl-9` | `workspace 1` through `workspace 9` |
| `alt-shift-1` through `alt-shift-9` | `move-node-to-workspace 1` through `9` |
| `alt-1` through `alt-9`, `alt-0` | `focus --tab-index 1` through `10` |
| `alt-shift-t` | `layout floating tiling` |
| `alt-shift-m` | `fullscreen` |
| `alt-slash` | `lens search` |
| `alt-shift-o` | `lens overview` |
| `alt-semicolon` | `mode lens` |

Option-Shift-O types `Ø` on US and ABC layouts when WinMux is not listening; the overview shortcut shadows that character. It has no shipped Lens-key or system symbolic-hotkey collision.

Cmd-Tab and Cmd-backtick stay with macOS. Alt-Tab, the bare-Control letters and the other removed chords are free for the focused app or another switcher.

The `lens` binding mode has six keys:

| Key | Commands |
| --- | --- |
| `o` | `mode main`, `lens overview` |
| `f` | `mode main`, `lens floating` |
| `s` | `mode main`, `lens search` |
| `r` | `mode main`, `lens recent --presentation list` |
| `a` | `mode main`, `lens app-windows --presentation list` |
| `esc` | `mode main` |

The five Lens values are ordered command lists: `mode main` runs before the Lens starts opening. This **Leaving the `lens` mode** default makes panel Escape available whether the Lens opens or fails. `winmux list-modes --current` reports `main` while it is open. A `lens` command by itself leaves the active binding mode alone, including a user's sticky mode named `lens`.

`winmux list-lenses --json` lists resolved Lens settings and Filter paths. It does not list Triggers; those belong to `mode.<name>.binding` in the loaded config. `winmux list-columns --json` prints `[]` when Columns are off. Both commands print valid JSON and exit 0 on success, 1 on runtime failure and 2 on bad usage. See [Lenses](lenses.md), [Columns](columns.md) and [subscription events](events.md).

Lens keys include `cmd-g = "sections next"`. Lists and grids draw workspace sections by default;
their Search row has the grouping control. During a Command Hold, a `g` in a list or grid runs
that binding; a strip treats it as a letter and converts to a list. See [Sections](lenses.md#sections-and-the-grouping-control).


## Opt in to Cmd-Tab

Merge these three lines into the record over your imported defaults:

```nickel
mode.main.binding.cmd-tab = "lens recent",
mode.main.binding.cmd-shift-tab = "lens recent",
mode.main.binding.cmd-backtick = "lens app-windows",
```

Cmd-Tab and Cmd-Shift-Tab then open WinMux's recent-window strip instead of Apple's app switcher; Cmd-backtick opens the same-app strip. WinMux disables the matching enabled system Cmd-Tab pair while the mode listens to those chords. Native Cmd-backtick remains enabled; WinMux handles its registered chord. Removing the bindings, leaving their mode, disabling WinMux or quitting restores the shortcuts WinMux held. Signal exits restore them too. A hard kill cannot restore them: relaunch WinMux, then quit normally to repair and restore the saved system shortcuts. Wake and unlock repair remains in place for configs that opt in.

## For people upgrading

Importing defaults now gives the short list above. Previously inherited chords disappear on upgrade; your own bindings remain. To retain any of the removed commands, paste the lines you want inside the record merged over defaults. This is also the migration block for this release. The future windowing mode is separate work.

```nickel
mode.main.binding.alt-cmd-1 = "project 1",
mode.main.binding.alt-cmd-2 = "project 2",
mode.main.binding.alt-cmd-3 = "project 3",
mode.main.binding.alt-cmd-4 = "project 4",
mode.main.binding.alt-cmd-5 = "project 5",
mode.main.binding.alt-cmd-6 = "project 6",
mode.main.binding.alt-cmd-7 = "project 7",
mode.main.binding.alt-cmd-8 = "project 8",
mode.main.binding.alt-cmd-9 = "project 9",
mode.main.binding.alt-cmd-h = "project prev",
mode.main.binding.alt-cmd-j = "swap down",
mode.main.binding.alt-cmd-k = "swap up",
mode.main.binding.alt-cmd-l = "project next",
mode.main.binding.alt-cmd-shift-1 = "move-node-to-project 1",
mode.main.binding.alt-cmd-shift-2 = "move-node-to-project 2",
mode.main.binding.alt-cmd-shift-3 = "move-node-to-project 3",
mode.main.binding.alt-cmd-shift-4 = "move-node-to-project 4",
mode.main.binding.alt-cmd-shift-5 = "move-node-to-project 5",
mode.main.binding.alt-cmd-shift-6 = "move-node-to-project 6",
mode.main.binding.alt-cmd-shift-7 = "move-node-to-project 7",
mode.main.binding.alt-cmd-shift-8 = "move-node-to-project 8",
mode.main.binding.alt-cmd-shift-9 = "move-node-to-project 9",
mode.main.binding.alt-cmd-shift-h = "move-node-to-project prev",
mode.main.binding.alt-cmd-shift-l = "move-node-to-project next",
mode.main.binding.alt-n = "focus dfs-next",
mode.main.binding.alt-p = "focus dfs-prev",
mode.main.binding.alt-shift-tab = "focus tab-prev",
mode.main.binding.alt-space = "layout horizontal vertical",
mode.main.binding.alt-tab = "focus tab-next",
mode.main.binding.cmd-tab = "lens recent",
mode.main.binding.cmd-shift-tab = "lens recent",
mode.main.binding.cmd-backtick = "lens app-windows",
mode.main.binding.cmd-ctrl-h = "workspace prev",
mode.main.binding.cmd-ctrl-l = "workspace next",
mode.main.binding.cmd-shift-h = "join-with left",
mode.main.binding.cmd-shift-i = "balance-sizes",
mode.main.binding.cmd-shift-j = "join-with down",
mode.main.binding.cmd-shift-k = "join-with up",
mode.main.binding.cmd-shift-l = "join-with right",
mode.main.binding.ctrl-0 = "workspace 10",
mode.main.binding.ctrl-cmd-shift-h = "stack-with left",
mode.main.binding.ctrl-cmd-shift-j = "stack-with down",
mode.main.binding.ctrl-cmd-shift-k = "stack-with up",
mode.main.binding.ctrl-cmd-shift-l = "stack-with right",
mode.main.binding.ctrl-e = "workspace 13",
mode.main.binding.ctrl-f = "open-sidebar",
mode.main.binding.ctrl-h = "workspace prev",
mode.main.binding.ctrl-l = "workspace next",
mode.main.binding.ctrl-q = "workspace 11",
mode.main.binding.ctrl-r = "workspace 14",
mode.main.binding.ctrl-shift-0 = "move-node-to-workspace 10",
mode.main.binding.ctrl-shift-h = "move-node-to-workspace --focus-follows-window prev",
mode.main.binding.ctrl-shift-l = "move-node-to-workspace --focus-follows-window next",
mode.main.binding.ctrl-t = "workspace 15",
mode.main.binding.ctrl-w = "workspace 12",
```
