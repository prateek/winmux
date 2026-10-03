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

Leaving the import out supplies no default Lenses or bindings. `winmux config convert` imports defaults and merges converted TOML settings over them, including individual bindings; it keeps the five Lenses and the `lens` binding mode. `config-version` is removed by conversion and rejected in Nickel. `persistent-workspaces` needs no version gate and defaults to an empty list. Workspace bindings do not implicitly declare persistent workspaces.

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
| `o` | `lens overview`, `mode main` |
| `f` | `lens floating`, `mode main` |
| `s` | `lens search`, `mode main` |
| `r` | `lens recent --presentation list`, `mode main` |
| `esc` | `mode main` |

The first four values are ordered command lists. A rejected Lens still runs the second command, returning to `main`. A successful Lens returns from the leader before presenting its panel, so Escape cancels the Lens rather than invoking the leader's binding. `winmux list-modes --current` reports `main` while the Lens is open.

`winmux list-lenses --json` lists resolved Lens settings and Filter paths. It does not list Triggers; those belong to `mode.<name>.binding` in the loaded config. `winmux list-columns --json` prints `[]` when Columns are off. Both commands print valid JSON and exit 0 on success, 1 on runtime failure and 2 on bad usage. See [Lenses](lenses.md), [Columns](columns.md) and [subscription events](events.md).
