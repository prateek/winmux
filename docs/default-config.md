# Default config and modes

With no config file, WinMux loads `winmux/defaults.ncl`. Columns are off, so new windows use ordinary tree tiling. Startup does not write a starter file unless it is converting a legacy config. “Open config” creates an editable import-only starter when needed.

The sidebar's expanded width defaults to 320 points. `workspace-sidebar.tree.splits`
and `workspace-sidebar.tree.columns` are Boolean defaults, both `false`. They reveal
split/floating groupings and Column slots respectively. Each workspace's buttons
override those defaults for the session. Changing a default clears its overrides;
the other toggle keeps its choices. Explicit sidebar widths are preserved.

`restore-windows-on-quit` is a Bool, default `true`. Quitting WinMux, from its menu, the system's Quit or logout, or SIGTERM, SIGINT and SIGHUP, puts each window that was open when WinMux started back at the frame it had then. A window moved to another display or resized by hand still goes back to that frame. A window opened while WinMux ran stays where it is, and one parked on a hidden workspace is centred on its display. A window whose recorded display is gone stays where it is if it is on screen, and is otherwise centred on the nearest display. The records live in memory for one run of WinMux: a config reload keeps them, and a closed window is never reopened. Set `restore-windows-on-quit = false` to centre every window at its last floating size, as earlier versions did.

`url-scheme` is a Bool, default `true`. Set it to `false` to refuse `winmux://` URL commands; a config reload applies to the next URL. [URL commands](url-scheme.md) has the form, the refused commands and who can use it.

## Settings shows what is loaded

Open **Settings…** from the menu bar to see the loaded file and time, Lenses and their Triggers, searchable bindings in every mode, Columns per workspace, hooks, Behavior and Appearance. Search accepts config notation such as `cmd` and modifier glyphs such as `⌘`. Filter functions stay in the config helper and appear on the Lenses that use them.

Settings edits nothing. **Open Config** opens the config file in its default editor, creating a starter only if no file exists. **Config File** shows the text on disk; **Reload From Disk** refreshes that display without applying it. Save a valid edit to apply it when `reload-on-save` is on, or use the menu's Reload config action. A failed load displays its diagnostic above every pane and keeps the last good values; a failed first load displays the built-in defaults. A later successful load clears the banner while Settings stays open. Double-sided windows is switched from the menu bar menu; Settings shows its current state.

## Importing defaults

```nickel
let W = import "winmux/winmux.ncl" in
(import "winmux/defaults.ncl") | W.Config
```

Defaults use field priorities that let an ordinary merge change one value. Modes own
keys and their lifetime; Lenses own their Filter, Presentation and view settings.
`mode.<name>.binding` remains valid sugar for a keymap block named `mode-<name>` with
`context = "mode == <name>"` and priority 1.

```nickel
let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  mode.main.binding.alt-l = W.open "floating" 'browse,
  keymap.terminal = W.when "app == 'com.mitchellh.ghostty'" { ctrl-semicolon = 'pass },
}) | W.Config
```

A binding value is a command, a command list, or `'pass`. `'pass` leaves the key to
the app; `[]` consumes it without running a command. Remove a field with
`W.without-bindings`; a replacement record needs `| force` to keep Nickel from
merging the omitted field back in:

```nickel
let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in
(defaults & {
  keymap.window.bindings | force = W.without-bindings ["t"] defaults.keymap.window.bindings,
}) | W.Config
```

`lenses.<name>.enabled = false` disables a Lens and preserves its other overrides.
Its opener fails with exit 2; remove or rebind the opener too. Omitting the defaults
import supplies no shipped keys or Lenses. Collections a person extends are records;
ordered values such as commands and sort keys are lists replaced whole.

## The 41 default shortcuts

| Binding in `main` | Command |
| --- | --- |
| `alt-h/j/k/l` | `focus left/down/up/right` |
| `alt-shift-h/j/k/l` | `move left/down/up/right` |
| `ctrl-1` through `ctrl-9` | `workspace 1` through `workspace 9` |
| `alt-shift-1` through `alt-shift-9` | `move-node-to-workspace 1` through `9` |
| `alt-1` through `alt-8`, and `alt-9` | `focus --tab-index 1` through `8`, and `focus --tab-index last` |
| `alt-shift-t` | `layout floating tiling` |
| `alt-shift-m` | `fullscreen` |
| `alt-slash` | `mode search-hold` |
| `alt-shift-o` | `mode overview-hold` |
| `alt-semicolon` | `mode window` |
| `alt-shift-semicolon` | `mode window-once` |

Holding the tab digits' modifier for half a second shows reachable tab keys on the
focused tab group. Option-Shift-O shadows the US/ABC `Ø` character. Cmd-Tab and
Cmd-backtick remain with macOS until opted in below.

## Shipped modes

| Mode | Lifetime | Unbound | Entry | Release | Draw delay |
| --- | --- | --- | --- | --- | --- |
| `main` | latched | pass | — | — | 0 ms |
| `window` | latched | pass | — | — | 0 ms |
| `browse` | latched | consume | — | — | 0 ms |
| `search` | latched | type | — | — | 0 ms |
| `cmd-tab`, `cmd-tab-back` | held | latch to browse | open recent; back steps prev | focus, then main | 100 ms |
| `cmd-backtick` | held | latch to browse | open app-windows | focus, then main | 100 ms |
| `search-hold` | held | latch to search | open search | mode search | 0 ms |
| `overview-hold` | held | latch to browse | open overview | mode browse | 0 ms |
| `window-once` | transient | consume | — | return to entering mode after one key | 0 ms |

`lifetime`, `unbound`, `on-enter`, `on-release`, `draw-delay` and `count` are mode
properties. `latch-to` must name an existing mode whose own `unbound` is not
`latch`; app loading and `config check` reject other targets. Counts default to
false. A mode with no explicit `unbound` passes keys unless an `on-enter` command opens a Lens, in
which case it consumes them. A held committing mode defaults to 100 ms of draw
delay; other modes draw immediately. CLI entry into a held mode is latched and
prints a note on stderr, since no entering chord supplies its modifiers.

The library exposes `W.Mode`, `W.Keymap`, `W.switcher`, `W.hold`, `W.open`,
`W.transient`, `W.when`, `W.keys`, `W.modes` and `W.keymap`. The shared key sets are
`main-today`, `navigate`, `workspaces`, `columns` (currently empty), and `lenses`.
Their fields have default priority, so `&` overrides a member.

In `browse`, arrows and hjkl move, Tab marks, Enter focuses, Shift-Enter and
Option-Enter Summon, Space/Y peek, G changes sections, and `/` converts to a list
and enters `search`. In `search`, unbound keys edit Search, including clipboard
chords; bound chords win. Escape returns to `browse` with text and matches kept;
a second Escape closes the Lens and enters `main`. The HUD names every mode but
`main`, including `browse` and `search`. `list-modes --current` reports that name.

## The windowing mode

`window` has 45 keys. Focus (`hjkl`), move (Shift-hjkl), join (Control-hjkl),
workspace digits and Shift-digits, tab-next/prev (`n`/`p`), `find-focus` (`c`),
floating/tiling (`t`), fullscreen (`m`) and project next/prev (brackets) stay on.
Escape and Option-semicolon return to `main`. The six Lens letters are pairs:

| Key | Commands |
| --- | --- |
| `w`, `o`, `f` | open windows, overview, floating; then `mode browse` |
| `s` | open search; then `mode search` |
| `r`, `a` | open recent or app-windows with `--presentation list --tile text`; then `mode search` |

`main`'s bindings are inactive in `window`. Unbound keys reach the app, as before.
Outside a Lens panel with key focus, unregistered keys reach the app even when a
mode says consume, type or latch; they end a transient mode and cancel a pending
sequence or count. See the related pre-key-panel limit in [Lenses](lenses.md#modes-and-keys).

## Keymap contexts, sequences and counts

Expressions use `==`, `!=`, `&&`, `||`, `!` and parentheses. Values are bare
identifiers or single-quoted strings; Columns comparisons use integers.

| Variable | Example | Meaning |
| --- | --- | --- |
| mode | `mode == browse` | Current mode |
| app | `app == 'com.mitchellh.ghostty'` | Frontmost app other than WinMux, by bundle id |
| lens | `lens == recent`, or `lens` | Open named Lens, or any open Lens including ad-hoc |
| presentation | `presentation == strip` | Open Lens's Presentation |
| columns | `columns == 3`, or `columns` | Focused workspace's Column count, or Columns enabled |
| profile | `profile == default` | The implicit profile; other profiles await Display profiles |

Absent Lens/Columns comparisons are false for equality and true for inequality.
An ad-hoc Lens is present but has no name. Specificity is the number of top-level
`&&` conjuncts; a parenthesised group or `!` counts as one. Greater specificity
wins, then greater priority. `W.when` defaults to priority 1; shipped blocks use
0. Equal ties are errors unless the contexts have top-level equality conjuncts
that cannot both hold. A complete chord conflicting with a sequence prefix is
also an error. `config check` names the block for invalid contexts and chords.

```nickel
let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  mode.counting = { count = true, unbound = 'consume, on-enter = "lens windows" },
  keymap.counting = W.when "mode == counting" { l = "lens step next", "g t" = "lens step prev" },
}) | W.Config
```

A sequence has no timeout. Pending chords appear beside the mode in the HUD.
Carbon captures its first chord in every app while its mode is current. This
also applies to legacy sequences: `esc-h` captures Escape in every app while
that mode is current.
Continuations win; a non-continuing key cancels the sequence and is read fresh.
An unbound Escape cancels only the pending sequence. A mode change cancels it.
Continuations register as soon as the prefix arrives. While entry modifiers are
held, Carbon registers only each chord's entry-modified alias; plain keys become
registered after a latch or release. A key Lens panel receives plain and Shift
keys itself, with composition state, while Command, Control and Option chords
stay registered. Main's bindings that resolve as global commands stay registered
while a Lens is open.
`"m <r>" = "mark <r>"` in `W.when` expands over `a` through `z`; the shipped
window mode keeps `m` as fullscreen, so it ships no conflicting mark sequence.
With `count = true`, unbound digits build a count and the next bound command list
runs that many times, in order. Any other key resets the count.
Zero runs the list zero times; accumulated counts stop at 9999.
The generated `mode-<name>` block name is reserved while that mode has bindings;
a same-named explicit block is a configuration error.

## Opt in to Cmd-Tab

Merge this block over defaults:

```nickel
let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  keymap.cmd-tab-opt-in = W.when "mode == main" {
    cmd-tab = "mode cmd-tab",
    cmd-shift-tab = "mode cmd-tab-back",
    cmd-backtick = "mode cmd-backtick",
  },
}) | W.Config
```

Tab steps the recent strip and Shift-Tab steps back while Command is down;
Command-W closes the selected window. Release focuses the selection. Cmd-backtick
uses the same lifetime over the same-app grid. The matching native Cmd-Tab pair
is held only while successful Carbon registrations need it. Removing those
bindings, changing context, disabling WinMux or quitting restores what it took.
Signal exits restore too; after a hard kill, relaunch and quit normally to repair.

## Migration: Lens keys become modes

A Lens no longer accepts `keys`, `starts-in` or `on-release`; `config check`
names the replacing mode property. Popup lists become Boolean records.
On an installed build, a config containing a removed Lens field fails to load.
WinMux runs on the built-in defaults and keeps the reason on screen until you
fix the config.

| Old Lens setting | Rewrite |
| --- | --- |
| `keys.cmd-x = "close"` | mode/keymap `cmd-x = "lens close-window"` |
| `keys.cmd-1 = "move-node-to-workspace 1"` | `cmd-1 = "lens run move-node-to-workspace 1"` |
| `starts-in = 'search` | opener `W.open "name" 'search`, or mode with `unbound = 'type` |
| `starts-in = 'normal` | opener `W.open "name" 'browse`, or mode with `unbound = 'consume` |
| `on-release = 'commit` | a held mode with `on-release = ["lens focus", "mode main"]` |
| `on-release = 'stay` | a held mode with `on-release = "mode browse"` or `"mode search"` |
| `popups = ['accessory-popup]` | `popups.accessory-popup = true` |

Replace `cmd-tab = "lens recent"` with `cmd-tab = "mode cmd-tab"` (and use
`cmd-tab-back` for Cmd-Shift-Tab). Replace Option-slash's `"lens search"` with
`"mode search-hold"`. Every hand-written `lens <name>` opener needs a mode or a
`W.open` pair if it should operate from the keyboard: a Lens opened alone leaves
the current mode unchanged. Empty command lists now consume; use `'pass` to free
a chord. Reads of `defaults.mode.main.binding` and `.window.binding` become
`defaults.keymap.main.bindings` and `.window.bindings`.

`config convert` preserves user modes and omitted upstream chords. It adds the
shipped Option-slash/Option-Shift-O commands only where unbound, and adds `window`
plus Option-semicolon only when neither existed. Converted files keep the other
shipped mode definitions and keymap blocks alongside the six Lenses. No-mode TOML
keeps all defaults. Version keys remain accepted and ignored; workspace
persistence is explicit, with the existing legacy TOML inference and warning.

`list-lenses --json` reports view settings, not keys. A standalone `lens` command
never enters a mode. The earlier keyboard's removed commands remain available;
copy the lines needed into a record merged over defaults:

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
mode.main.binding.cmd-tab = "mode cmd-tab",
mode.main.binding.cmd-shift-tab = "mode cmd-tab-back",
mode.main.binding.cmd-backtick = "mode cmd-backtick",
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
