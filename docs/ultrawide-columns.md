# Ultrawide Columns

WinMux organizes windows with five nouns. A **Display** (a physical monitor)
shows one **Scene** at a time; a scene is a left-to-right arrangement of
**Columns**; each column behaves like its own small monitor and holds a stable
ordered **Deck** of **Cards** (a card is a named window group), showing one card
at a time; **Rules** deal newly opened windows onto cards by matching them. A
laptop needs none of this: with no scene declared, the display gets one implicit
full-width column whose deck is all your cards, and you page it like classic
workspaces.

Use this guide to go from a laptop to a split ultrawide without reading the
implementation plan. The config surface is `config-version = 3`; a config that
still uses the old `zone-*` keys or commands will error. See
[config-v3-migration.md](config-v3-migration.md) for the old-to-new map.

## Install

Install WinMux, then launch it once so macOS can ask for permissions.

```bash
xattr -dr com.apple.quarantine /Applications/WinMux.app/
open /Applications/WinMux.app
```

WinMux reads `~/.config/winmux/winmux.toml` by default. If the file does not
exist, WinMux creates one from `resources/default-config.toml`, which ships the
laptop case (no scenes) with a commented ultrawide example near the bottom.

## Permissions

Open System Settings and grant the permissions WinMux needs:

- Accessibility: lets WinMux inspect and move windows.
- Screen Recording: lets WinMux build previews and run Exposé.
- Automation: lets configured commands drive apps when you opt into AppleScript
  or app automation.
- Input Monitoring: lets global keyboard and mouse bindings work.

Check the current state with:

```bash
winmux doctor
```

## From Zero: The Laptop Case

The default config declares no scene, so your single display gets one implicit
full-width column. Every card lives in that column's deck, and you page the deck
the way you used to switch workspaces:

- `alt-n` / `alt-p` — next / previous card in the deck.
- `alt-1` … `alt-9`, `alt-0` — jump to a card by its deck position.
- `alt-tab` — bounce between the last two cards.

Deck positions are stable, so muscle memory holds. Inspect the deck at any time:

```bash
winmux list-cards                 # one card name per line (the '%{workspace}' token)
winmux list-cards --focused
```

Cards are born, not declared. New windows join the focused card. To make a fresh
card, send a window to a new name (this creates the card if it does not exist):

```bash
winmux move-node-to-card Scratch  # creates 'Scratch' and moves the focused window into it
```

Rules (below) create cards automatically, and `persistent-cards` keeps named
cards alive even when empty. There is no bare "empty card" command; a card comes
into being when a window or a rule puts something in it, or when you page past
the end of the deck.

## Splitting an Ultrawide Into Columns

To carve an ultrawide into side-by-side columns, declare a scene. Add this to
`~/.config/winmux/winmux.toml` (or uncomment the example block in the default
config):

```toml
[scene.desk]
display = 1
default-column = 'main'          # where rule-created cards land
columns = [
  { id = 'ref',   name = 'Reference', width = 0.20, color = '#3EA2FF' },
  { id = 'main',  name = 'Work',      width = 0.55 },
  { id = 'comms', name = 'Comms',     width = 0.25, color = '#D3455B' },
]
```

Notes:

- `display` selects the physical monitor: `1`, `2` (left-to-right order),
  `'main'`, `'secondary'`, or a display-name pattern like `'LG-Ultrawide'`.
  Prefer names for stable multi-monitor setups.
- `width`s are fractions of the display and should sum to `1.0`.
- `color` tints the column's chrome (divider, sidebar accent, Exposé border).
  It is purely cosmetic.
- Column `id`s may not use the reserved direction words `left`, `right`, `next`,
  or `prev` — config validation rejects them so `card move right` stays
  unambiguous.

Check the file before relying on it:

```bash
winmux config --check ~/.config/winmux/winmux.toml
```

Each column is its own small monitor with its own deck. Move focus and cards
between columns with column mode. The default config binds `alt-z` to enter it:

```toml
[mode.column.binding]
h = ['focus-column prev', 'mode main']
l = ['focus-column next', 'mode main']
shift-h = ['card move left', 'mode main']
shift-l = ['card move right', 'mode main']
minus = ['column resize -10%', 'mode main']
equal = ['column resize +10%', 'mode main']
"0" = ['balance-columns', 'mode main']
t = ['column toggle', 'mode main']
esc = 'mode main'
```

The same moves are plain CLI calls:

```bash
winmux focus-column comms          # left | right | next | prev | <column-id>
winmux card move comms             # move the focused card to the 'comms' column
winmux card move right             # ...or to the adjacent column, clamped at the edge
winmux column resize +10% comms    # widen a column (omit the id to resize the focused one)
winmux column collapse comms       # hide a column; 'expand' restores it; 'toggle' flips it
winmux balance-columns             # equalize widths
```

If you prefer the assistant over hand-editing, `column init` writes a starter
scene block:

```bash
winmux column init --dry-run --preset balanced
winmux column init --preset balanced --write
```

Presets are `balanced` (Reference 25% / Work 50% / Comms 25%), `focus-only`
(narrow sides, wide Work), `comms-open` (Comms gets more room), and `dashboard`
(adds a fourth Dashboard column). `--write` keeps a timestamped backup and
refuses to overwrite an unmanaged block unless you pass `--replace-existing`.

## Multiple Scenes on One Display

A display can switch between several scenes. Declare more than one for the same
`display`; the first declared is the default:

```toml
[scene.desk]
display = 1
default-column = 'main'
columns = [
  { id = 'ref',   name = 'Reference', width = 0.20, color = '#3EA2FF' },
  { id = 'main',  name = 'Work',      width = 0.55 },
  { id = 'comms', name = 'Comms',     width = 0.25, color = '#D3455B' },
]

[scene.focus]                       # one wide Work column
display = 1
columns = [ { id = 'main', name = 'Work', width = 1.0 } ]

[scene.triage]                      # lead with Comms
display = 1
default-column = 'comms'
columns = [
  { id = 'comms', name = 'Comms', width = 0.60, color = '#D3455B' },
  { id = 'main',  name = 'Work',  width = 0.40 },
]
```

Switch scenes by name or cycle them. The default config puts scenes on the
`ctrl` layer so they never collide with the `alt-<number>` card positions:

```toml
alt-ctrl-1 = 'scene desk'
alt-ctrl-2 = 'scene focus'
alt-ctrl-3 = 'scene triage'
alt-ctrl-tab = 'scene next'
```

```bash
winmux scene focus                  # switch the focused display to a scene
winmux scene next                   # cycle that display's scenes
```

Scenes are **live, not snapshots**. Whatever you leave in a scene — which card
each column shows, the column widths — is exactly what you find when you switch
back. Switching away only stops the outgoing scene from rendering; nothing is
destroyed. A card always belongs to exactly one column of one scene.

`scene new <name>` names the current live arrangement as a new scene (handy on a
laptop: it turns the implicit column into a named scene you can switch back to):

```bash
winmux scene new deck
```

## Day to Day

**Keyboard, all day.** `alt-n` / `alt-p` page the deck you are looking at;
`alt-3` jumps to a known position; `alt-tab` bounces between two cards mid-task.
`alt-ctrl-1` is the desk, `alt-ctrl-2` is full-width focus. Because decks are
stable, positions stay put and muscle memory works.

**Triage hour.** Slack pings pile up. Pull the Chat card into the big center
column while you deal with them, then send it home when you are done:

```bash
winmux card summon Chat             # move the Chat card into the focused column
winmux card move comms              # ...and send it back to the Comms column
```

Or switch to a dedicated `triage` scene and back — both arrangements survive
untouched.

**Mouse.** Drag a window with the secondary button held and it snaps into a
column. Enter column mode (`alt-z`) and the dividers grow handles for width
drags; outside column mode the boundaries are inert, so ordinary clicks never
fight the window manager.

```toml
[mouse]
column-divider-drag = 'column-mode'  # handles only in column mode; 'always' | 'off'

[mouse.column-snap]
policy = 'float-unless-snap'          # freeform | snap-on-modifier | snap-to-column
modifier = 'alt'
gesture = 'secondary-button-drag'
target = 'column'                     # or 'window' to snap into an in-column slot
```

With `float-unless-snap`, an ordinary drag leaves the window floating; holding
the gesture shows the column overlay and snaps on release. `target = 'window'`
snaps onto a slot inside an existing window (overlay `Window slot: Right`)
instead of onto the whole column.

**Sidebar as the map.** The sidebar shows every scene, column, and deck at once,
with the showing card highlighted per column — it is the cross-scene view that
Exposé (live pixels of the active scene only) cannot give you. Click a card to
focus it, expand it to see its windows, rename in place. Drag a card row to
another column's section to move it, or drop it on a scene chip to send it to
that scene. Open the sidebar with `ctrl-f` (`open-sidebar`).

**Leader Key / Raycast.** Every command is equally a key binding, a CLI call,
and a launcher action, so launcher tools get the whole surface for free. A
Leader Key namespace:

```json
{ "key": "w", "name": "winmux", "actions": [
  { "key": "d", "name": "desk",       "action": "winmux scene desk" },
  { "key": "f", "name": "focus",      "action": "winmux scene focus" },
  { "key": "t", "name": "triage",     "action": "winmux scene triage" },
  { "key": "c", "name": "pull chat",  "action": "winmux card summon Chat" },
  { "key": "b", "name": "build",      "action": "winmux card go Build" },
  { "key": "s", "name": "stash",      "action": "winmux move-node-to-card Scratch" },
  { "key": "m", "name": "mute comms", "action": "winmux column collapse comms" },
  { "key": "=", "name": "balance",    "action": "winmux balance-columns" },
  { "key": "e", "name": "overview",   "action": "winmux expose display" }
]}
```

`card go <name>` reveals an existing card wherever it lives, switching that
display's scene if the card is hidden; it errors on an unknown name rather than
creating one. `move-node-to-card <name>` stashes the focused window into a card,
creating it if new. A Raycast script command is one line —
`winmux card go "$1"` with a card-name argument — and `winmux list-cards` feeds
Raycast a picker (one card name per line).

## Rules: Dealing Windows Onto Cards

A rule is a window match to a card, never a place. Rules evaluate top to bottom;
the first match wins unless it sets `check-further-rules = true`. A rule naming a
card that does not exist yet creates it in the active scene's `default-column`,
independent of where focus happens to be. Unmatched windows join the focused
card, as usual.

```toml
[[rules]]
if.app-id = 'com.tinyspeck.slackmacgap'   # bundle id (most precise)
card = 'Chat'

[[rules]]
if.app-name-regex-substring = 'Mail|Messages'
card = 'Chat'

[[rules]]
if.window-title-regex-substring = 'Pull Request|Issue'
card = 'Review'
focus = true                              # focus the card once the window lands
```

Keep rule-target cards alive even when empty so their home is stable:

```toml
persistent-cards = ['Chat', 'Review']
```

## Overview (Exposé)

The default config binds `ctrl-up` to an overview of the active scene and
`ctrl-down` to an overview of the focused card's windows:

```toml
ctrl-up = 'expose display'
ctrl-down = 'expose card'
```

Select a tile with arrows and Return, a number key, or a click; Escape closes.
Previews come from cached screenshots captured after transitions and need the
Screen Recording permission (the first overview prompts once); without it tiles
show labels only. macOS's own Mission Control shortcuts may shadow
Ctrl+Up/Down — disable them in System Settings > Keyboard > Shortcuts > Mission
Control if nothing happens.

## Persistence

Runtime state persists automatically; there is no save command. Column widths,
each column's showing card, and every deck's card order are written to
`deck-state.json` in WinMux's Application Support directory (debounced) and
restored on the next launch. The config file declares the scene skeletons
(columns, default widths, colors); the live deck contents and any width changes
you make at runtime live in the state file. Editing and reloading the config
never loses a card — a card whose column disappears merges, order preserved,
into the display's default column.

## Troubleshooting

Start with these:

```bash
winmux config --check ~/.config/winmux/winmux.toml
winmux doctor
winmux list-columns
winmux list-cards --all
winmux list-windows --focused
```

`list-columns` prints each column's id, name, enabled state, effective width,
color, physical monitor, and the card it is showing. If a column looks missing,
`column expand <column-id>` restores a collapsed one. If a config edit errors,
the message names the offending key and its v3 replacement; restore a backup
that `column init --write` or `config` left behind:

```bash
winmux config --restore-backup /path/to/winmux.toml.backup-YYYYMMDDTHHMMSSZ
```

## Support Bundle

For beta reports, generate a local support bundle:

```bash
winmux doctor zones --support-bundle --output ~/Desktop/winmux-support
```

(The `zones` keyword is the retained subcommand name for this diagnostic.) The
bundle is an attachable directory with redacted config, monitor topology, active
cards, column decks, permissions, and log boundaries. It uploads nothing. Window
titles are redacted by default; pass `--include-window-titles` only if the
titles are safe to share.

## Sample Configs

Complete, parse-checked samples live under `docs/samples/`:

- `laptop-minimal.toml` — zero scenes; the implicit-column laptop case.
- `ultrawide-three-column.toml` — one scene, three columns, with rules.
- `scenes-desk-focus-triage.toml` — three scenes on one display.
- `rules-routing.toml` — routing windows onto cards by match.
- `mouse-and-expose.toml` — snap policies, divider drags, and Exposé.

Check one before copying it:

```bash
winmux config --check docs/samples/laptop-minimal.toml
```

## Updates

The menu bar's "Check for Updates..." fetches the dogfood appcast on demand.
Background checks are off unless you opt in:

```toml
[updates]
automatic-check = true
```

## Known Limits

- Columns are vertical slices, not a freeform rectangle editor.
- Mouse snap supports whole-column and in-column window-slot targets, but not
  arbitrary freeform grid cells.
- Removing a scene is a config edit (there is no delete-scene command yet); its
  cards merge into the display's default scene's default column.
- Cards are created by rules, `move-node-to-card <name>`, a numbered deck slot,
  or `persistent-cards`; there is no standalone "new empty card" command.
