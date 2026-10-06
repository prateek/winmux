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

Leaving the import out supplies no default Lenses or bindings. `winmux config convert` imports the five default Lenses. If the TOML has a `mode` table, conversion replaces the default modes with the TOML's modes and adds the fork's `lens` mode keys and five `main` Triggers, only where the TOML has no binding for those keys. Modifier order, keyboard presets and key aliases are resolved as in the Swift loader. Omitted upstream bindings stay omitted, and a user's `cmd-tab` command wins. Duplicate user spellings of the same chord fail conversion with a binding redeclaration diagnostic, and so does a `mode` table with no `main` mode. The converted modes are merged at normal priority, so a record merged over the converted file later can still add or change a binding. With no `mode` table, conversion keeps all default modes and bindings. A comment in the converted file describes the retained defaults and how to remove them.

`config-version` is optional, accepted and ignored for compatibility with earlier Nickel conversions, like `contract-version`. It is absent from shipped defaults and new conversions; both version keys are removed before the Swift settings parser runs. Nickel uses an explicit `persistent-workspaces` list, defaulting to empty. For TOML version 1 or lower, or an absent version, conversion preserves the old inferred persistence when the file sets no list: it writes workspace targets from every mode's `workspace` and `move-node-to-workspace` bindings, followed by force-assignment keys, in first-seen order, and prints a warning. A quoted name is one target. When nothing is inferred it writes no list and prints no warning. Relative `next` and `prev` targets declare no workspace. Version 2 and an explicit list suppress inference.

The upstream bindings keep their commands. The fork adds these Triggers:

| Binding in `main` | Command |
| --- | --- |
| `cmd-tab`, `cmd-shift-tab` | `lens recent` |
| `cmd-backtick` | `lens app-windows` |
| `alt-slash` | `lens search` |
| `alt-semicolon` | `mode lens` |

`alt-tab` and `alt-shift-tab` keep upstream's tab focus commands. The `lens` binding mode has five keys:

| Key | Commands |
| --- | --- |
| `o` | `mode main`, `lens overview` |
| `f` | `mode main`, `lens floating` |
| `s` | `mode main`, `lens search` |
| `r` | `mode main`, `lens recent --presentation list` |
| `esc` | `mode main` |

The first four values are ordered command lists: `mode main` runs before the Lens starts opening. This **Leaving the `lens` mode** default makes panel Escape available whether the Lens opens or fails. `winmux list-modes --current` reports `main` while it is open. A `lens` command by itself leaves the active binding mode alone, including a user's sticky mode named `lens`.

`winmux list-lenses --json` lists resolved Lens settings and Filter paths. It does not list Triggers; those belong to `mode.<name>.binding` in the loaded config. `winmux list-columns --json` prints `[]` when Columns are off. Both commands print valid JSON and exit 0 on success, 1 on runtime failure and 2 on bad usage. See [Lenses](lenses.md), [Columns](columns.md) and [subscription events](events.md).

Lens keys include `cmd-g = "sections next"`. Lists and grids draw workspace sections by default;
their Search row has the grouping control. During a Command Hold, a `g` in a list or grid runs
that binding; a strip treats it as a letter and converts to a list. See [Sections](lenses.md#sections-and-the-grouping-control).
