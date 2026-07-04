# Slice 56: Domain Model Simplification

Status: implemented across phases A–G and shipping. This document is the
authoritative design — the Model, Policies, Config v3, and Commands sections
describe the behavior that ships; the Phases section records how it was built.

## Context

winmux's user surface grew to ~12 overlapping nouns, and three of them
(workspace, zone, scene) compete to be the primary organizing concept. The
sidebar is a flat workspace list and settings has no zones surface. Slice 56
replaces the surface with five nouns. The runtime architecture (zone =
monitor-like viewport hosting a workspace) does not change.

## The model

- **Display** — physical monitor. Shows exactly one **scene** at a time.
- **Scene** — a named arrangement a display can switch to: a set of
  columns. A scene is live, not a snapshot. Changes you make in it stick,
  and switching back shows it exactly as you left it.
- **Column** — vertical slice within a scene. It behaves as its own small
  monitor: it holds a stable ordered **deck** of cards and shows one.
  Width and color are attributes.
- **Card** — named window group (runtime = workspace). Strict containment:
  a card lives in exactly one column's deck, in exactly one scene, always.
  Summoning is moving. Cards move (or drag, in the sidebar) between
  columns and between scenes.
- **Rule** — window match → card, never a place.

How the nouns map to upstream winmux:

| New | Upstream winmux |
|---|---|
| Display | monitor. Upstream shows one workspace per monitor; a display here shows one scene, whose columns each behave as a monitor to the runtime |
| Scene | no upstream equivalent — it names "which workspace is where" across a whole display, something upstream leaves implicit |
| Column | no upstream equivalent visually; each column is a monitor to the runtime, so upstream focus/move/layout machinery works on it unchanged |
| Card | workspace, given an owner: it lives in a column's deck instead of floating in the global pool |
| Deck | not a sixth noun — the ordered contents of a column (was the sidebar's per-project workspace ordering, re-keyed to columns) |
| Rule | a new declarative match→card table reusing upstream's matcher engine; `on-window-detected` itself stays parsed but undocumented |

Upstream's projects are deleted (cards are the grouping users see) and
its tab groups survive only as in-card window tabbing. The fork's own
zone-era vocabulary (zones, zone-scenes, zone-layouts, availability sets,
bindings, affinities, styles) maps in `docs/config-v3-migration.md`.

Off-screen cards keep their one place in some column of some scene, and
the sidebar shows it. Expose shows the active scene, since it renders
live pixels; the sidebar is the cross-scene view. In-card window layout
(tiles, accordion, tabs) is a property of the card via the upstream
`layout` command.

A display with no configured scene gets one implicit scene with one
full-width column whose deck is all its cards. That is the laptop case:
zero config, classic workspace switching.

## Policies

- **Rename what the fork owns; keep what upstream owns.**
  Upstream-inherited identifiers (`Workspace`, `MacWindow`, the tree and
  layout machinery) keep AeroSpace names so merges stay cheap. Everything
  fork-authored renames to the model: `ZoneTopology`→`ColumnTopology`,
  `ZoneMonitor`→`ColumnMonitor`, zone UI/diagnostics/command files →
  column/card/scene names. New types are born with model names
  (`ColumnDeckStore`, `SceneRegistry`). The boundary is file provenance;
  fork-added files are zone*/sidebar/tabs/scenes by construction.
  Glossary in AGENTS.md and the Workspace.swift header: Card=Workspace
  (upstream name), Column=the fork's viewport-monitor, Deck=per-column
  card order.
- **Hard cut, no compat.** Config v3 rejects dead keys with a one-line
  old→new hint. Old command names are removed. Old format tokens are
  replaced by `%{card-name}`, `%{column-id}`, `%{column-name}`, etc.
  Historical `check-slice-*` checkers and accepted artifacts stay
  untouched; they validate frozen files, not live behavior. Migration is
  a mapping doc (`docs/config-v3-migration.md`) plus doctor hints, no
  auto-migrator. `on-window-detected` stays parsed only because it is
  upstream code: deleting it buys merge friction, keeping it costs
  nothing. It drops out of fork docs.
- **`card N` addresses deck position.**
- **Where new things land, one rule each.** An unmatched new window joins
  the focused card (upstream behavior). `card new` creates in the focused
  column. A rule naming a nonexistent card creates it in the active
  scene's `default-column` on the display where the window appeared;
  rules must not depend on where focus happens to be.
- **`card go` never creates**; an unknown name is an error. Creation
  belongs to `card new`, rules, and `scene new` only.
- **Focus follows visibility on card moves.** `card move` keeps focus on
  the card when its destination is visible (a column of the focused
  display's active scene) and leaves focus behind when it is not; the
  vacated column shows its deck's next card. `card summon` always ends
  focused. `card go` reveals: it switches the owning display's scene if
  needed and focuses the card. `card move left|right` clamps at the
  display edge.
- **Scene switching never destroys state.** The outgoing scene's cards
  keep their scene and column membership and simply stop rendering
  (mechanically the same hide path invisible workspaces use today).
- **Scene commands act on the focused display**, the display hosting the
  focused column. `scene next` cycles that display's scenes.
- **Removing a scene** (config edit today; a delete command can come
  later) merges its decks, order preserved, into the display's default
  scene's default column, the same orphan-merge rule hotplug uses.
  Removing the default scene promotes the next declared one; removing
  the last brings back the implicit scene.
  `scene new <name>` works at any time: it names the current live
  arrangement as a scene (on an implicit-scene display the columns and
  deck carry over and the implicit scene ceases to exist). Colliding
  names error; `next` and `new` are reserved scene names, like the
  direction words for column ids.
- **Upstream posture.** AeroSpace (nikitabobko) is the merge-relevant
  upstream; its internals keep their names, untouched. The direct origin
  (zimengxiong/winmux, source of projects, tab groups, and the sidebar)
  becomes effectively one-way after this slice: projects die and the
  sidebar is restructured. That divergence is accepted.
- **Binding modes are not a domain noun.** They stay the upstream
  chorded-keys mechanism. The template ships two: `main` and `column`.

## Config v3 — the complete surface

```toml
config-version = 3
start-at-login = true
auto-reload-config = true

# Inside a card, windows use the upstream layout system: tiles, accordion,
# or the fork's window tabs. These set the defaults; the `layout` command
# changes it per card at runtime.
default-root-container-layout = 'tiles'
default-root-container-orientation = 'auto'

[window-tabs]                # in-card window tabbing (presentation only)
enabled = true
height = 36

[gaps]
inner.horizontal = 8
inner.vertical = 8
outer.left = 8
outer.top = 8
outer.right = 8
outer.bottom = 8

[sidebar]                    # was workspace-sidebar; project keys are gone
enabled = true
width = 240
collapsed-width = 44
show-status-pills = true
show-date = true

[updates]
automatic-check = false

[mouse]
# Dividers are draggable only while the binding mode named 'column' is
# active ('column-mode'), always, or never.
column-divider-drag = 'column-mode'   # | 'always' | 'off'
[mouse.column-snap]          # was zone-snap
# policies: float-unless-snap | freeform (never snap) | snap-on-modifier
# | snap-to-column
policy = 'float-unless-snap'
modifier = 'alt'
gesture = 'secondary-button-drag'
target = 'column'            # or 'window' for in-column slot snapping

# Scenes own the columns. A display shows one scene at a time; declare as
# many scenes per display as you switch between. `display` selects the
# PHYSICAL monitor: 1, 2 = left-to-right order; 'main'; 'secondary'; or a
# display-name pattern ('LG-Ultrawide') — prefer names for stable
# multi-monitor setups. The first declared scene for a display is its
# default. A display with no scene gets an implicit one-column scene (the
# laptop case).
[scene.desk]
display = 1
default-column = 'main'      # where rule-created cards land
columns = [
  # color tints the column's chrome: divider, sidebar section accent,
  # expose tile border. Purely cosmetic. Column ids may not use the
  # reserved direction words (left/right/next/prev) — config validation
  # rejects them so `card move right` stays unambiguous.
  { id='ref',   name='Reference', width=0.20, color='#3EA2FF' },
  { id='main',  name='Work',      width=0.55 },
  { id='comms', name='Comms',     width=0.25, color='#D3455B' },
]

[scene.focus]                # fewer columns is fine: full-width Work
display = 1                  # default-column omitted = the first column
columns = [ { id='main', name='Work', width=1.0 } ]

[scene.triage]               # a third scene on the same display
display = 1
default-column = 'comms'
columns = [
  { id='comms', name='Comms', width=0.60, color='#D3455B' },
  { id='main',  name='Work',  width=0.40 },
]

# Rules deal new windows onto cards by name.
[[rules]]
if.app-id = 'com.tinyspeck.slackmacgap'
card = 'Chat'
[[rules]]
if.window-title-regex-substring = 'Inbox|Mail'
card = 'Chat'

# Cards listed here are never pruned, even when empty.
persistent-cards = ['Scratch']

[mode.main.binding]
alt-n = 'card next'
alt-p = 'card prev'
alt-tab = 'card back-and-forth'
alt-1 = 'card 1'             # deck position in the focused column
alt-2 = 'card 2'
alt-ctrl-1 = 'scene desk'    # scenes get the ctrl layer; no collision
alt-ctrl-2 = 'scene focus'
alt-h = 'focus left'         # window focus, upstream
alt-shift-l = 'move-node-to-column right'
ctrl-up = 'expose display'
ctrl-down = 'expose card'
alt-z = 'mode column'

[mode.column.binding]        # was mode zone
h = ['focus-column prev', 'mode main']
l = ['focus-column next', 'mode main']
shift-h = ['card move left', 'mode main']
shift-l = ['card move right', 'mode main']
minus = ['column resize -10%', 'mode main']
equal = ['column resize +10%', 'mode main']
"0" = ['balance-columns', 'mode main']
t = ['column toggle', 'mode main']
s = ['cycle-column-snap-policy float-unless-snap freeform', 'mode main']
esc = 'mode main'
```

`[scene.*]` parses into the existing `ZoneConfig`/`ZoneLayoutConfig`
structs, extended: `ZoneColumnConfig` gains `color` (zone-styles folds
into the column literal), `ZoneConfig` gains the scene id and
`default-column`. Config declares scene skeletons; decks and per-scene
runtime state live in the persisted state file. Version gate at
`parseConfig.swift:215-220` bumps to 3. Renamed keys:
`workspace-sidebar`→`sidebar`, `mouse.zone-snap`→`mouse.column-snap`
(target `zone`→`column`), `mouse.zone-divider-drag`→
`mouse.column-divider-drag`, `persistent-workspaces`→`persistent-cards`.
Dead keys (hard error naming the replacement): zones, zone-layouts,
zone-scenes, and zone-availability-sets → `[scene.*]`; zone-styles →
column `color`; zone-affinities → `[[rules]]`; zone-bindings → nothing
(decks replace them); project sidebar keys → removed. Card-level layout has no per-card
config block on purpose: it is runtime state via the upstream `layout`
command, with the global defaults above.

## Commands

### Reference

| Command | Arguments | Effect |
|---|---|---|
| `card next` / `card prev` | — | page the focused column's deck |
| `card <N>` | deck position | show the Nth card of the focused column |
| `card go` | `<name>` | focus a card wherever it lives, revealing its scene if hidden |
| `card back-and-forth` | — | bounce between the last two cards in this column |
| `card summon` | `<name>` | move the named card into the focused column |
| `card move` | `left\|right`, `<column-id>`, or `<scene>:<column>` | move the focused card |
| `card new` | `<name>` | new empty card, top of the focused deck |
| `move-node-to-card` | `<name>` | move the focused window to a card |
| `move-node-to-column` | `left\|right` or `<column-id>` | move the focused window to a column |
| `focus-column` | `left\|right\|next\|prev` or `<column-id>` | move focus between columns |
| `column resize` | `±<pct>` or `<pct>` `[<column-id>]` | resize the focused (or named) column |
| `column collapse` / `expand` / `toggle` | `[<column-id>]` | hide or restore a column |
| `column color` | `<hex> [<column-id>]` | tint a column's chrome |
| `column init` | `--preset <p> [--dry-run\|--write]` | write a starter scene block |
| `balance-columns` | — | equalize widths |
| `scene <name>` | — | switch the focused display to a scene |
| `scene next` | — | cycle the focused display's scenes |
| `scene new` | `<name>` | name a scene seeded from the current columns |
| `expose` | `display\|card` | overview of the active scene, or of the focused card's windows |
| `list-cards` / `list-columns` | `[--format <tokens>]` | machine-readable state (`%{card-name}`, `%{column-id}`, ...) |
| `set-column-snap-policy` / `cycle-column-snap-policy` | policy names | mouse snap behavior |

Direction words (`left`, `right`, `next`, `prev`) are reserved; config
validation rejects column ids that use them. Every command is equally a
key binding, a CLI call, and a launcher action — that is the integration
story.

### How people will actually drive it

**Keyboard, all day.** `alt-n`/`alt-p` page the deck you are looking at;
`alt-3` jumps to a known position; `alt-tab` bounces between two cards
mid-task. `alt-ctrl-1` is the desk; `alt-ctrl-2` is full-width focus.
Positions stay put because decks are stable, so muscle memory works.

**Triage hour.** Slack pings pile up. `winmux card summon Chat` pulls the
Chat card into the big center column; when the hour is over,
`winmux card move comms` sends it home — or you switch to a dedicated
`triage` scene and back, and both arrangements survive untouched.

**Mouse.** Drag a window with the secondary button held and it snaps into
a column (or a slot within one, with `target='window'`). Enter column
mode (`alt-z`) and the dividers grow handles for width drags; outside
column mode the boundaries are inert, so ordinary clicks never fight the
window manager. In the sidebar, drag a card row to another column's
section to move it; drop it on a scene chip to send it to that scene.

**Sidebar as the map.** Every scene, column, and deck is visible; the
showing card is highlighted per column. Click a card to focus it; expand
it to see its windows; rename in place. The sidebar is the whole state.

**Leader Key / Raycast.** Because the CLI is the same surface as the
bindings, launcher tools get everything for free. A Leader Key namespace:

    { "key": "w", "name": "winmux", "actions": [
      { "key": "d", "name": "desk",        "action": "winmux scene desk" },
      { "key": "f", "name": "focus",       "action": "winmux scene focus" },
      { "key": "t", "name": "triage",      "action": "winmux scene triage" },
      { "key": "c", "name": "pull chat",   "action": "winmux card summon Chat" },
      { "key": "b", "name": "build",       "action": "winmux card go Build" },
      { "key": "n", "name": "scratch",     "action": "winmux card new Scratch" },
      { "key": "m", "name": "mute comms",  "action": "winmux column collapse comms" },
      { "key": "=", "name": "balance",     "action": "winmux balance-columns" },
      { "key": "e", "name": "overview",    "action": "winmux expose display" }
    ]}

A Raycast script command is one line: `winmux card go "$1"` with a
card-name argument, or `winmux list-cards --format '%{card-name}'` to
feed Raycast a picker.

Deleted commands: all zone-binding commands (deck membership already
records which cards belong where), project commands, and the eight
use/cycle-zone-{layout,scene,availability,profile} names (profile was an
alias of availability) → scene. The metadata chain updates in lockstep:
cmdArgsManifest → cmdHelpGenerated → subcommandDescriptions →
check-command-metadata. This section seeds the rewritten
`docs/ultrawide-columns.md`.

## Phases

Semantic core first under existing names; vocabulary cut second, as a
mechanical and separately reviewable diff while the existing test suite
is still a meaningful net. New surfaces (scene, rules) are born with
final names. Each phase ends green and dogfood-releasable.

**A — Deck store + strict containment** (the risk lives here)
- New `tree/ColumnDeckStore.swift`: `decksByColumnKey: [String:
  [WorkspaceId]]` keyed by scene id + column id — both config-declared
  names, so the key survives display reorder and resolution changes
  alike. Implicit scenes have no config name and key by display identity
  instead: name pattern when the display reports one, physical geometry
  otherwise (Risk 2 covers that remainder). Lives inside
  `WinMuxWorkspaceState` so registry mutations maintain it atomically.
  Reconciliation logic ports from `pruneProjectWorkspaceIndexes`
  (`WinMuxWorkspaceState.swift:185-205`).
- New `tree/persistedDeckState.swift` (pattern:
  `persistedFrozenWorld.swift`): versioned JSON, card names not session
  ids, debounced save, load before first reconciliation.
- Survival predicate rewrite (`WorkspaceLifecycle.swift:196-207`), TDD
  table first: visible / has windows / configured-persistent / sole card
  in deck / retained deck slot / hidden active card of a disabled column
  (so re-enabling restores the exact card it was showing). A deck is
  never empty, so a sole card survives even when it is an auto-created
  blank; blanks are prunable only while the deck holds something else. Deletes zone parking
  (`parkedWorkspaceByZoneId`, `ZoneTopology.swift:380`) and project
  sole-survivor; `WorkspaceRetainedEmptySlot` rekeys to column.
- Invariants in `checkWorkspaceHierarchyInvariants`
  (`WorkspaceMonitorAssignment.swift:144`): every live card in exactly
  one deck; a viewport's active card belongs to its deck. (Archived is
  the pre-existing lifecycle state for closed-but-restorable cards; an
  archived card leaves its deck and rejoins one on restore.)
- Hotplug: extend the three-tier viewport remap
  (`WorkspaceMonitorAssignment.swift:196-215`) to remap deck keys;
  orphaned decks merge, order preserved, into the display's default deck.
- `Workspace.get(byName:)` adopts new cards into the focused column's
  deck, which also preserves test-fixture behavior.
- Support bundle gains a deck section with new headers; existing header
  lines stay byte-identical.

**B — Deck navigation + summon-as-move**
- `workspace next|prev` candidate source: project → focused column's deck
  (`WorkspaceCommand.swift:146`; traversal at :174-188 reused).
- `SummonWorkspaceCommand` and `MoveWorkspaceToMonitorCommand` become
  deck transfers wrapping
  `activateWorkspaceOnMonitorPreservingSourceViewport`
  (`WorkspaceMonitorAssignment.swift:47-67`); fallback synthesis draws
  from the deck, not the project.

**C — Scenes as contexts**
- `SceneRegistry` (active scene per display) replaces the preset fields
  of `ZoneRuntimeOverlay`: `activeSceneId` predates this slice (it
  tracked zone-scenes) and carries over as the selector for the new
  scenes; `activeLayoutId`, `activeAvailabilitySetId`, and
  `styleOverridesByZoneId` die with their concepts. Their readers
  (ConfigDoctor, ZoneSupportBundle, UseZoneLayoutCommand) update in
  Phase E.
- Scene switch rebuilds the incoming scene's column viewports through the
  zone-layout activation path (`setActiveZoneLayout`,
  `ZoneTopology.swift:1438`), because scenes can differ in column count;
  it then restores each column's active card from its deck.
  `overrideWorkspaceOnMonitorBySwappingActiveViewports`
  (`WorkspaceMonitorAssignment.swift:70-97`) stays the primitive for
  per-column re-points and cross-scene card moves. The outgoing scene's
  cards hide automatically: `layoutWorkspaces` already corner-hides every
  non-visible workspace each pass. The rollback-snapshot pattern
  (`ZoneTopology.swift:1429-1437`) guards structural failure; it is an
  edit transaction, unrelated to scene semantics.
- `[scene.*]` parsing; `command/impl/SceneCommand.swift`
  (`scene <name>|next|new`). `scene new` writes a skeleton block from
  live columns and widths through the managed-edit machinery
  (`ZoneLayoutConfigEdits.swift`), backing up the config first. Cross-scene
  `card move <scene>:<column>` is a deck transfer.

**D — Rules**
- New `parseRules.swift` reusing `WindowDetectedCallbackMatcher` and the
  matcher engine (`WindowDetectedRuleInspection.swift:75-134`) verbatim;
  routing through the `MoveNodeToWorkspaceCommand` path (content) rather
  than `MoveNodeToZoneCommand` (place). Unmatched windows join the focused
  card, as today. A rule naming a missing card creates it in the scene's
  `default-column` through a dedicated creation path, not
  `Workspace.get(byName:)`, whose focused-column default serves
  interactive creation.

**E — Vocabulary cut**
- Config v3 gate + dead-key errors; command renames/deletions + metadata
  chain; `zone init` → `column init` (`ZoneInitConfig.swift:82-109`
  emits a `[scene.*]` block); overlay-reader updates from Phase C land
  here (ConfigDoctor, ZoneSupportBundle, UseZoneLayoutCommand); prune
  dead-concept coverage from ZoneCommandTest.
- Preflight re-baseline: drop the frozen old-vocabulary guest self-test
  re-runs (the whole block, `makefile:188-206`). The 51-55 guest scripts
  are rewritten in new vocabulary for the deferred Tart proof, not just
  dropped.
- Fork-internals rename pass (mechanical, own commit): fork-authored
  types/files adopt model names; upstream-inherited files keep upstream
  names.

**F — Sidebar + settings** (incremental, not a rewrite)
- Generalize `WorkspaceSidebarZoneTargetSnapshotBuilder` into the
  column/deck section builder; promote
  `WorkspaceSidebarZoneTargetSection.swift` to the section container
  replacing the project pager; row and window item builders untouched;
  the implicit column renders as a single headerless section, so the
  laptop looks unchanged.
- Card-row drag payload in `WorkspaceSidebarDragPayload`/`DropTargets`/
  `DropDelegate`: reorder within a deck, transfer across columns and
  scenes (a scene switcher row exposes non-active scenes as drop
  targets).
- Delete the 12 `Project*` sidebar files and project command paths as an
  isolated commit, only after a visual-parity release.
- Settings (`ShortcutSettingsView.swift:34` pane enum): Columns / Scenes /
  Rules panes. Tray label, switcher palette, and expose strings adopt
  card/column vocabulary.

**G — Docs + template + proof**
- `resources/default-config.toml` template block; `docs/ultrawide-zones.md`
  rewritten and renamed `docs/ultrawide-columns.md`; five
  `docs/samples/*.toml`; `docs/config-v3-migration.md`; AGENTS.md
  glossary; plan-doc status.
- Reconcile the repo plan doc's Slice 56 section to the scene-as-container
  model.
- New slice-56 guest script + contract checker; then the deferred Tart
  verification phase runs for Slices 51-56 in final vocabulary.

## Risks

1. Strict containment vs pruning (lost cards, or blanks piling up) →
   survival-matrix TDD table first; auto-created blanks stay prunable
   except as a deck's sole card.
2. Implicit-scene decks on displays that report no usable name key by
   physical geometry, so a resolution change can orphan them →
   order-preserving orphan-merge into the display's default deck, deck
   section in the support bundle, hardware-UUID keying as a follow-up.
   Named scenes and columns are immune: their keys are config names.
3. Sidebar coupling (47KB view, drag and hover state) → builders first,
   parity release before Project* deletion, deletion isolated.
4. Test fixtures create free workspaces (`Workspace.get(byName:)` in 10+
   files) → implicit-deck adoption reproduces current behavior; full
   suite green at Phase A before anything stacks on it.

## Verification

TDD the survival matrix (A); deck navigation, positional `card N`, and
summon membership tests (B); scene round-trip (mutate a scene, leave,
return, assert it intact), cross-scene move, scene-removal orphan-merge,
and rollback tests (C); rule routing and placement tests — rule-created
cards land in `default-column` regardless of focus, `card new` in the
focused column (D); dead-key error and metadata checker tests (E); sidebar builder
and drag-policy tests mirroring `WorkspaceSidebarDragTest` (F). Full
`swift test` plus an adversarial review workflow at every phase boundary,
and a dogfood release after each phase (Sparkle makes upgrades
one-click). Finally the slice-56 Tart contract proof, then the deferred
51-56 verification phase.
