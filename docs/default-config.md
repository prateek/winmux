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

Remove mode bindings from the imported record with `W.without-bindings ["chord", …] bindings`. It ignores names that are already absent, so a later default change does not break your config. The replacement binding record must take precedence over the original record, otherwise Nickel's merge would put the removed field back:

```nickel
let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in
let without-search = defaults & {
  mode.main.binding | force = W.without-bindings ["alt-slash"] defaults.mode.main.binding,
} in
(without-search & { gaps.inner.horizontal = 4 }) | W.Config
```

For a Lens key, use an empty command list instead of removing the field:
`lenses.recent.keys.space = []` frees Space, and `lenses.recent.keys.cmd-y = []`
removes the other shipped peek key. Lens defaults restore omitted keys; this
explicit empty list survives that merge. A replacement such as
`lenses.recent.keys.cmd-p = "peek"` can be added alongside it.

To turn a shipped Lens off, set `lenses.recent.enabled = false` (using that Lens's name). Other Lens overrides continue to merge over the defaults. A binding that opens a disabled Lens then fails with exit 2, including the window mode's `w` for `windows`, `r` for `recent` and `a` for `app-windows`, and a Cmd-Tab opt-in: remove or rebind those keys too.

Leaving the import out supplies no default Lenses or bindings. `winmux config convert` imports the six default Lenses. If the TOML has a `mode` table, conversion replaces the default modes with the TOML's modes and adds two `main` Triggers, `alt-slash` and `alt-shift-o`, only where the TOML has no binding for those keys. It adds the `window` binding mode together with its `alt-semicolon` Trigger only when the TOML has neither a mode named `window` nor a binding for `alt-semicolon` in `main`; otherwise it adds neither, so a mode you wrote gains no keys and no mode arrives that nothing enters. Modifier order, keyboard presets and key aliases are resolved as in the Swift loader. Omitted upstream bindings stay omitted, and a user's `alt-slash` command wins over the added Search Trigger. A TOML's own Cmd-Tab bindings are preserved as explicit opt-ins. Duplicate user spellings of the same chord fail conversion with a binding redeclaration diagnostic, and so does a `mode` table with no `main` mode. The converted modes are merged at normal priority, so a record merged over the converted file later can still add or change a binding. With no `mode` table, conversion keeps all default modes and bindings. A comment in the converted file describes the retained defaults and how to remove them.

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
| `alt-semicolon` | `mode window` |

Option-Shift-O types `Ø` on US and ABC layouts when WinMux is not listening; the overview shortcut shadows that character. It has no system symbolic-hotkey collision. During its Hold, Return subtracts the Trigger’s own Option and Shift before matching and focuses. On the Option-slash Hold, Option-Return focuses and extra Shift-Return Summons. Option-slash opens the Search list; its first letter ends the Hold and becomes the first Search letter even with Option still down. Once the Hold ends, modifiers mean themselves: `alt-enter` Summons. Overview starts in normal mode: `hjkl` and arrows move, `/` starts Search, Escape returns to normal with the matches kept, and another Escape closes. The Search list starts in Search and also takes two Escapes to close. `starts-in` can override either choice.

Cmd-Tab and Cmd-backtick stay with macOS. Alt-Tab, the bare-Control letters and the other removed chords are free for the focused app or another switcher.

## The windowing mode

`alt-semicolon` enters the `window` binding mode. It has exactly these 44 keys:

| Key | Commands |
| --- | --- |
| `h`, `j`, `k`, `l` | `focus left`, `focus down`, `focus up`, `focus right` |
| `shift-h`, `shift-j`, `shift-k`, `shift-l` | `move left`, `move down`, `move up`, `move right` |
| `1` through `9` | `workspace 1` through `workspace 9` |
| `shift-1` through `shift-9` | `move-node-to-workspace 1` through `9` |
| `ctrl-h`, `ctrl-j`, `ctrl-k`, `ctrl-l` | `join-with left`, `join-with down`, `join-with up`, `join-with right` |
| `n`, `p` | `focus tab-next`, `focus tab-prev` |
| `t` | `layout floating tiling` |
| `m` | `fullscreen` |
| `rightSquareBracket`, `leftSquareBracket` | `project next`, `project prev` |
| `w` | `mode main`, `lens windows` |
| `o` | `mode main`, `lens overview` |
| `f` | `mode main`, `lens floating` |
| `s` | `mode main`, `lens search` |
| `r` | `mode main`, `lens recent --presentation list --tile text` |
| `a` | `mode main`, `lens app-windows --presentation list --tile text` |
| `esc` | `mode main` |
| `alt-semicolon` | `mode main` |

Only the six Lens letters, Escape and Option-semicolon leave the binding mode. Focus, movement, workspace changes and failed commands keep it on. `0` is unbound. Numeric workspace commands use the same workspace ordinals as `main`.

While it is on, `main`'s chords are off: Option-slash does not open Search, and Option-Shift-O does not open overview. Plain keys not bound in this binding mode reach the focused app; for example, `x` still types into a text field. WinMux does not swallow unbound keys.

A small HUD at the bottom centre of the focused monitor's visible frame shows the active binding mode's name. It follows monitor focus, takes neither keyboard focus nor mouse clicks, and shows no key hints. It appears for every binding mode other than `main`, including user-defined ones, with no setting to hide it. Disabling WinMux hides it. CLI mode changes and config reloads update it too; the menu bar keeps its existing single-letter indicator.

The six Lens values are ordered command lists: `mode main` runs and hides the HUD before the Lens starts opening. `winmux list-modes --current` reports `main` while the Lens is open, even if opening failed. A standalone `lens` command leaves the active binding mode alone, including a user's sticky binding mode named `lens`.

To remove a windowing key, merge this record over defaults:

```nickel
let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in
(defaults & {
  mode.window.binding | force = W.without-bindings ["t"] defaults.mode.window.binding,
}) | W.Config
```

`winmux list-lenses --json` lists resolved Lens settings and Filter paths. It does not list Triggers; those belong to `mode.<name>.binding` in the loaded config. `winmux list-columns --json` prints `[]` when Columns are off. Both commands print valid JSON and exit 0 on success, 1 on runtime failure and 2 on bad usage. See [Lenses](lenses.md), [Columns](columns.md) and [subscription events](events.md).

Lens keys include `cmd-g = "sections next"`. Lists and grids draw workspace sections by default;
their Search row has the grouping control. During a Command Hold, a `g` in a list or grid runs
that binding and keeps its Hold; in a strip it ends the Hold and stays in normal mode. `/` converts the strip to a list. See [Sections](lenses.md#sections-and-the-grouping-control).

The shipped `recent` Lens uses `tile = 'picture` and `grid.tile-size = 'same-height`; see [Tiles](lenses.md#tiles) for the cards-back recipe. `windows`, `app-windows` and `floating` use grids with card Tiles at real relative sizes. `app-windows` explicitly commits on release; `windows` and `floating` stay open. A config's existing `windows` Lens receives the grid Presentation at priority -1, so its own values win.

## Opt in to Cmd-Tab

Merge these three lines into the record over your imported defaults:

```nickel
mode.main.binding.cmd-tab = "lens recent",
mode.main.binding.cmd-shift-tab = "lens recent",
mode.main.binding.cmd-backtick = "lens app-windows",
```

Cmd-Tab and Cmd-Shift-Tab then open WinMux's recent-window strip instead of Apple's app switcher; Cmd-backtick opens the same-app grid, which commits on Command release. WinMux disables the matching enabled system Cmd-Tab pair while the mode listens to those chords. Native Cmd-backtick remains enabled; WinMux handles its registered chord. Removing the bindings, leaving their mode, disabling WinMux or quitting restores the shortcuts WinMux held. Signal exits restore them too. A hard kill cannot restore them: relaunch WinMux, then quit normally to repair and restore the saved system shortcuts. Wake and unlock repair remains in place for configs that opt in.

## For people upgrading

The shipped binding mode is now `window`; there is no default `lens` binding mode or alias. A config merging `mode.lens.binding.x = "focus left"` over defaults still loads: it creates a user-defined `lens` binding mode that the default Trigger never enters. Reading `defaults.mode.lens.binding` fails with a missing-field error; the helper prints a rename hint above Nickel's diagnostic. Change that read to `defaults.mode.window.binding`.

Files converted before this change contain their own `lens` binding mode and `alt-semicolon = "mode lens"`. They keep working as before and gain none of the new windowing keys. To adopt these keys, replace that binding mode with the new defaults and point the Trigger at `mode window`. A newly converted TOML gets the `window` binding mode and its Trigger only when it has neither a mode named `window` nor its own Option-semicolon binding.

`winmux mode <name>` still succeeds when no binding mode of that name exists. It makes that name current and registers no bindings. Recover with `winmux mode main` from the CLI; no new validation or alias was added.

The windowing mode restores access to these removed chords' commands: tab-next/tab-prev (formerly Alt-Tab/Alt-Shift-Tab), the four join directions (formerly Cmd-Shift-H/J/K/L), and project prev/next (formerly Alt-Cmd-H/L). Focus, move, workspace, floating/tiling and fullscreen commands also remain available here. Other removed commands still need explicit bindings; the paste block below keeps them available.

An old removal such as `std.record.remove "ctrl-w" defaults.mode.main.binding` now fails with ``error: missing field `ctrl-w` ``: Ctrl-W is no longer a default binding. One-line fix: delete that removal, or replace it with `W.without-bindings ["ctrl-w"] defaults.mode.main.binding`. The helper prints this advice above the original Nickel error. A config that fails evaluation cannot load; on startup WinMux falls back to its built-in defaults.

An earlier `config convert` wrote `mode.main.binding.cmd-tab = "lens recent"`, `mode.main.binding.cmd-shift-tab = "lens recent"` and `mode.main.binding.cmd-backtick = "lens app-windows"` as your own lines. They remain active after upgrading; delete those three lines to give Cmd-Tab back to macOS. Their Cmd-backtick now opens a grid that commits on release; to restore the old picture strip, merge `lenses.app-windows.presentation = 'strip`, `lenses.app-windows.tile = 'picture` and `lenses.app-windows.grid.tile-size = 'same-height` over defaults; it needs no `on-release` line.

The new defaults are `main`'s `alt-shift-o` and the windowing mode's `a` and `w`; an existing binding for any of them under another spelling, such as `shift-alt-o`, can fail with a binding redeclaration error, just as for other default chords.

Importing defaults now gives the short list above. Previously inherited chords disappear on upgrade; your own bindings remain. To retain any of the removed commands, paste the lines you want inside the record merged over defaults. This is also the migration block for this release.

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
