# Config v3 Migration

`config-version = 3` is a hard cut. The domain-model rewrite (Slice 56) retires
the fork's zone-era vocabulary and replaces the command surface with five nouns:
Display, Scene, Column, Card, Rule. There is no auto-migrator. Every dead or
renamed config key is a hard parse error whose message names its replacement, so
an old config fails loudly instead of silently parsing into a concept that no
longer exists.

This document is the complete old-to-new map. For the day-to-day guide in the
new vocabulary, see [ultrawide-columns.md](ultrawide-columns.md).

## How to migrate

1. Set `config-version = 3` at the top of your config.
2. Run the checker and fix each reported key from the tables below:

   ```bash
   winmux config --check ~/.config/winmux/winmux.toml
   ```

   Under v3 the checker stops at the first retired key it recognizes and prints
   the one-line replacement hint, so you may need to run it a few times as you
   clear keys.
3. Rebuild your zone layouts and scenes as `[scene.*]` blocks, your zone
   affinities as `[[rules]]`, and rename your commands and binding modes.

The mental-model shift: a zone was a fixed viewport that showed whatever
workspace you last put there. A **column** is a viewport that owns a stable
ordered **deck** of **cards**; a **scene** is the whole display's column
arrangement, and a display can switch between several scenes. "Which workspace
shows in which zone" (the old `[[zone-scenes]]`) is no longer a separate concept
— it is just the live state of a scene's decks, and it persists automatically.

## Dead and renamed top-level keys

Each of these is a hard error under `config-version = 3`. The "Replacement"
column is what to use instead.

| Old key | Status | Replacement |
|---|---|---|
| `[[zones]]` | removed | `[scene.*]` blocks (a scene's `columns` array) |
| `[[zone-layouts]]` | removed | `[scene.*]` blocks (columns + widths live in the scene) |
| `[[zone-scenes]]` | removed | `[scene.*]` — a scene's live decks are its per-column cards; no separate scene-to-workspace mapping |
| `[[zone-availability-sets]]` | removed | `[scene.*]` — declare a scene with fewer columns instead of hiding zones |
| `[[zone-styles]]` | removed | the column `color` attribute inside `[scene.*] columns` |
| `[[zone-affinities]]` | removed | `[[rules]]` |
| `[[zone-bindings]]` | removed | nothing — a column's deck records which cards belong to it |
| `[workspace-sidebar]` | renamed | `[sidebar]` |
| `persistent-workspaces` | renamed | `persistent-cards` |

## Renamed and removed sub-keys

| Old key | Status | Replacement |
|---|---|---|
| `[mouse.zone-snap]` | renamed | `[mouse.column-snap]` |
| `mouse.zone-divider-drag` | renamed | `mouse.column-divider-drag` |
| `sidebar.project-deletion-action` | removed | none — projects are gone |
| `sidebar.project-labels` | removed | none — projects are gone |
| `sidebar.project-colors` | removed | none — projects are gone |

## Reshaping zone layouts and scenes into `[scene.*]`

The old zone-layout / zone-scene / availability-set trio collapses into
`[scene.*]` blocks. Before:

```toml
[[zone-layouts]]
id = 'balanced'
layout = 'columns'
default-zone = 'main'
columns = [
  { id = 'left', name = 'Reference', width = 0.25 },
  { id = 'main', name = 'Work', width = 0.50 },
  { id = 'right', name = 'Comms', width = 0.25 },
]

[[zone-scenes]]
id = 'deep-work'
layout-preset = 'balanced'
workspaces = [
  { zone = 'left', workspace = 'FocusQueue' },
  { zone = 'main', workspace = 'FocusBuild' },
  { zone = 'right', workspace = 'FocusNotes' },
]

[[zone-styles]]
id = 'accent'
color = '#3EA2FF'

[[zone-availability-sets]]
id = 'focus-only'
enabled-zones = ['main']
```

After — one scene per arrangement you switch between, on a chosen `display`:

```toml
[scene.desk]
display = 1
default-column = 'main'          # was default-zone; where rule-created cards land
columns = [
  { id = 'left', name = 'Reference', width = 0.25, color = '#3EA2FF' },  # color folds in zone-styles
  { id = 'main', name = 'Work',      width = 0.50 },
  { id = 'right', name = 'Comms',    width = 0.25 },
]

[scene.focus]                    # replaces the 'focus-only' availability set: fewer columns
display = 1
columns = [ { id = 'main', name = 'Work', width = 1.0 } ]
```

Key-level mapping inside the block:

| Old (zone-layout / zone-scene / availability set) | New (`[scene.*]`) |
|---|---|
| `[[zone-layouts]] id = '...'` | the `[scene.<name>]` table name |
| `layout = 'columns'` | removed — scenes are always columns |
| `default-zone` | `default-column` |
| `columns = [{ id, name, width }]` | `columns = [{ id, name, width, color }]` |
| `[[zone-styles]] color` referenced by a zone | the column's `color` field, inline |
| `[[zone-scenes]] workspaces = [{ zone, workspace }]` | removed — a scene's decks hold its cards; deck state persists automatically |
| `[[zone-availability-sets]] enabled-zones` | a scene declaring only those columns |
| (no zone equivalent) | `display` — which physical monitor the scene belongs to |

The old `[[zone-scenes]]` "put workspace X in zone Y" mapping has no config
form: you move a card into a column once (in the app, the sidebar, or with
`card move`), and the deck remembers it across relaunches via `deck-state.json`.

## Renamed config values

The `[mouse]` sub-keys above are hard errors, but the value spellings inside a
correctly renamed block still accept both the old and the new token. Prefer the
v3 spelling:

| Setting | Old value | v3 value |
|---|---|---|
| `[mouse.column-snap] policy` | `snap-to-zone` | `snap-to-column` |
| `[mouse.column-snap] target` | `zone` | `column` |
| `mouse.column-divider-drag` | `zone-mode` | `column-mode` |

Binding modes are a naming convention, not a hard error. The template's divider
mode is renamed:

| Old | New |
|---|---|
| `[mode.zone.binding]` | `[mode.column.binding]` |
| `alt-z = 'mode zone'` | `alt-z = 'mode column'` |

The mode that arms divider drag under `column-divider-drag = 'column-mode'` is
the mode literally named `column`, so rename the block and the `mode` command
together or the dividers will arm in a mode your bindings do not use.

## Renamed commands

| Old command | New command |
|---|---|
| `focus-zone <zone>` | `focus-column <column>` (`left\|right\|next\|prev\|<column-id>`) |
| `move-node-to-zone <zone>` | `move-node-to-column <column>` (`left\|right\|<column-id>`) |
| `resize-zone <zone> width ±N%` | `column resize ±N% [<column-id>]` |
| `enable-zone <zone>` | `column expand [<column-id>]` |
| `disable-zone <zone>` | `column collapse [<column-id>]` |
| `toggle-zone <zone>` | `column toggle [<column-id>]` |
| `set-zone-style <zone> <color>` | `column color <hex> [<column-id>]` |
| `balance-zones [--monitor <m>]` | `balance-columns [--monitor <m>]` |
| `zone init` | `column init` (emits a `[scene.*]` block; presets unchanged) |
| `list-zones` | `list-columns` |
| `list-workspaces` | `list-cards` |
| `move-node-to-workspace <name>` | `move-node-to-card <name>` |
| `set-zone-snap-policy <policy>` | `set-column-snap-policy <policy>` |
| `cycle-zone-snap-policy <policy>...` | `cycle-column-snap-policy <policy>...` |
| `zone-expose zone` | `expose card` |
| `zone-expose display` | `expose display` |
| `workspace <name>` | `card go <name>` |
| `workspace <N>` | `card <N>` (deck position in the focused column) |
| `workspace next\|prev` | `card next\|prev` |
| `workspace-back-and-forth` | `card back-and-forth` |
| `summon-workspace <name>` | `card summon <name>` |
| `move-workspace-to-monitor <dir>` | `card move left\|right` (also `card move <column-id>` and cross-scene `card move <scene>:<column>`) |

## Removed commands

These commands are gone with no drop-in rename. The "Do this instead" column is
the capability's new home.

| Removed command | Do this instead |
|---|---|
| `use-zone-layout <id>` | `scene <name>` |
| `cycle-zone-layout <ids>...` | `scene next` |
| `use-zone-scene <id>` | `scene <name>` |
| `cycle-zone-scene <ids>...` | `scene next` |
| `use-zone-availability <id>` | `scene <name>` (a scene with fewer columns) |
| `cycle-zone-availability <ids>...` | `scene next` |
| `use-zone-profile <id>` | `scene <name>` (profile was an availability alias) |
| `cycle-zone-profile <ids>...` | `scene next` |
| `set-zone-style` / `cycle-zone-style` | `column color <hex>` |
| `save-zone-layout` | nothing — widths and deck state persist automatically to `deck-state.json`; `scene new <name>` names the current arrangement as a scene |
| `export-zone-layout` | nothing — no config export; edit `[scene.*]` directly or use `column init` / `scene new` |
| `apply-zone-bindings` | nothing — a column's deck already records card membership |
| `bind-node-to-zone` | `move-node-to-card <name>` or a `[[rules]]` match |
| `unbind-node-zone-binding` | nothing — move the card out of the column instead |
| `list-zone-bindings` | `list-cards` or the sidebar (shows every column's deck) |
| `project` | nothing — projects are gone; cards are the grouping users see |
| `move-node-to-project <name>` | `move-node-to-card <name>` |

The eight `use/cycle-zone-{layout,scene,availability,profile}` selectors all
fold into the single `scene` command: switching a layout, a scene mapping, or an
availability set are the same operation now — switching which scene a display
shows.

## `--format` interpolation tokens

Only the list commands were renamed; the `--format` interpolation token
spellings are unchanged (they keep their upstream `monitor-zone-*` names
internally). Update the command name, keep the tokens:

| Old | New |
|---|---|
| `list-zones --format '...'` | `list-columns --format '...'` |
| `list-workspaces --format '...'` | `list-cards --all --format '...'` |

Useful tokens, by list command:

| Token | Meaning | Use with |
|---|---|---|
| `%{workspace}` | card name (the default `list-cards` format) | `list-cards` |
| `%{monitor-zone-id}` | column id | `list-columns` |
| `%{monitor-zone-name}` | column name | `list-columns` |
| `%{monitor-active-workspace}` | the card the column is showing | `list-columns` |
| `%{monitor-zone-enabled}` | whether the column is expanded | `list-columns` |
| `%{monitor-zone-effective-width}` | the column's current width fraction | `list-columns` |
| `%{monitor-zone-style-color}` | the column's color hex | `list-columns` |

Tokens tied to retired concepts still parse but now return empty:
`%{monitor-zone-layout-id}`, `%{monitor-zone-availability-set-id}`, and
`%{monitor-zone-style-id}` — layouts, availability sets, and style ids no longer
exist. Drop them from format strings.

## Routing: zone affinities to rules

App and window routing moves from `[[zone-affinities]]` to `[[rules]]`, and it
now names a **card** (content), not a zone (place):

```toml
# Before
[[zone-affinities]]
zone = 'Comms'
if.app-id = 'com.apple.mail'
if.window-title-regex-substring = 'Inbox|Mail'
fail-if-noop = false

# After
[[rules]]
if.app-id = 'com.apple.mail'
if.window-title-regex-substring = 'Inbox|Mail'
card = 'Comms'
```

A rule naming a card that does not exist yet creates it in the active scene's
`default-column`. The upstream `[[on-window-detected]]` callback still parses but
is undocumented in the fork; prefer `[[rules]]` for window routing.
