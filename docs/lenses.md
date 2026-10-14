# Lenses and Search

A Lens combines a Filter, sort order, a Presentation and commands for its selected window.
Import `winmux/defaults.ncl` to get `search`, `floating`, `overview`, `recent` and `app-windows`.
Alt-slash opens `search`; alt-shift-o opens `overview`. Alt-semicolon enters the `window` binding mode: `o` opens `overview`, `f` opens `floating`, `s` opens `search`, `r` opens `recent` as a list and `a` opens `app-windows` as a list. Cmd-tab, cmd-shift-tab and cmd-backtick are unbound by default. Opt in with the three lines in [Default config](default-config.md#opt-in-to-cmd-tab) to replace the system app switcher with the recent strip and reach the same-app strip. See [default Triggers](default-config.md). `palette` is an alias for
`lens search`; without that Lens both commands fail.

```nickel
let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  filters.tiled = fun w ctx => w.class == 'tiled,
  lenses.work = {
    filter = filters.tiled,
    presentation = 'list,
    starts-in = 'normal,
    sort = ['mru, 'title],
    keys.cmd-x = "close",
    when.default.enabled = true,
  },
  mode.main.binding.alt-l = "lens work",
}) | W.Config
```

Omitting `filter` matches every candidate. Candidates include minimized windows and windows
of hidden apps. Candidate AX reads overlap and keep tree order; a window whose record cannot
be read is omitted from that open. Popup classes are excluded unless listed in `popups`. The one active Display
profile is `default`; other `when` records load but do not apply. `strip` fits every match in centred rows; `miniatures` draws workspace copies; `grid` packs every match into sections. Lists and grids group by workspace unless `sections` chooses another grouping.

```sh
winmux list-lenses --json
winmux lens search --search 'release notes'
winmux lens --filter "w.class == 'floating" --sort mru,title
printf '%s' 'w.app.name == "Editor"' | winmux lens --filter -
winmux list-windows --lens work --json
winmux list-windows --search 'release notes' --workspace focused --json
winmux summon --window-id 42
```

## Tiles

Every Presentation draws an entry through the same Tile. `tile` chooses its kind:

| Kind | Drawing |
| --- | --- |
| `card` | App icon and title above a picture at the window's aspect ratio. |
| `picture` | Picture with a corner icon; the selected title is in the Presentation's footer. |
| `text` | Icon, title, app name and chips on one line, without a picture. |

A config Lens with no explicit Tile defaults to `card` in a strip and `text` in a list. Card and picture lists both keep the
one-line title bar and add a small picture at the left. Miniatures always uses `picture` and
accepts `tile = 'picture`, including in `when.default`, and rejects `card` and `text`. A grid defaults to `card`. The Lens contract leaves `tile` absent so Swift can
resolve it after a Presentation override.

The shipped `recent` and `app-windows` Lenses use `tile = 'picture` and
`grid.tile-size = 'same-height`: pictures share a row height and the selected title stays
in the footer. To get the previous card strips with relative window sizes back, merge:

```nickel
let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  lenses.recent.tile = 'card,
  lenses.recent.grid.tile-size = 'real,
  lenses.app-windows.tile = 'card,
  lenses.app-windows.grid.tile-size = 'real,
}) | W.Config
```

With the cards-back recipe, `/` from the strip gives a list of card rows, since a Lens has one Tile kind; for text rows set `tile = 'text` on a list Lens of your own.

A shipped picture strip converted with `/` or `winmux lens --presentation list` keeps
its picture rows. The windowing mode's `r` and `a` explicitly choose `--tile text`.

`badges` defaults to `true`. Chips show the sidebar's workspace label for another workspace: its number when it has one,
otherwise its display name, truncated after twelve characters with an ellipsis. These are followed by
`floating`, `minimized` or `hidden` when applicable. `badges = false` removes these chips;
marks, Summon labels, Frozen looks and the Accessory outline/tag remain. App entries use the
app name as their title and retain their window-count chip. Chips stay beside a title: a picture-only
strip or grid puts the selected entry's chips in its footer, and miniatures puts them after the selected
title under its workspace cell, omitting the workspace chip that the cell already names.
Pictures carry the corner icon, mark, Summon label and Frozen/Accessory treatments. List rows
of every kind keep the mark, Summon label and Accessory tag at the trailing end of the line.

```nickel
lenses.recent.tile = 'text,
lenses.work = { presentation = 'list, tile = 'card, badges = false },
```

`winmux lens recent --tile picture` overrides the kind for one opening. A `--presentation`
override resolves the default for that Presentation unless the Lens configured a kind.
`--tile` with miniatures, whether configured or selected by `--presentation`, exits 2 before
opening. The override needs a Lens name or `--filter`; converting an already open Lens with
`lens --presentation list` does not accept it. `list-lenses --json` reports the resolved `tile`
and `badges`, including the active `when.default` profile.

Tile measurements scale by the smaller of visible width / 1920 and visible height / 1080.
The list panel starts at 760 points wide with a 30-point radius at that scale. It grows when the grouping control needs more room; its Search field scales too. Its height
fits its rows, up to two thirds of the visible height; its top stays a quarter of the way down, which leaves
a margin below a full list. Refreshes request only a viewport-sized window around selection.

Pictures keep their window's shape, including in list rows; a missing picture shows the app
icon in that shape. A strip uses the grid's sizing: fit (`same-height`) clamps allocation aspects to 0.6–2.1,
while `real` keeps relative window sizes and `equal` uses equal 1.5:1 boxes. An extreme picture
is centred at its real shape inside that allocation, with no filled or outlined box behind it. The aspect comes from the same rectangle as capture and stays fixed while the Lens is open.
Card and picture strip selections lift without changing layout or hit regions. Text rows use
a tinted plate; miniatures uses a four-point ring without scaling.

`--lens`, `--filter` and `--search` imply all workspaces if no scope flag is present; with an
explicit scope the result is the intersection. They include minimized windows that bare
`list-windows --all` does not. Search JSON includes `score` and `matched-field`; multiple matched
fields are comma-separated. Filters stay in the helper. `list-lenses --json` identifies a Filter
by the config path it is set at, such as `lenses.floating.filter`, or `null` when absent.
The path is a label, not something a `--filter` expression can call.
A `when.default.filter` takes precedence and reports that path.
A disabled Lens makes both `lens <name>` and `list-windows --lens <name>` exit 2 with the
same diagnostic and no stdout. A failed script Filter prints no stdout. New commands return 0 for success, 1 for an unavailable
server/helper, and 2 for bad usage or a bad Filter.

Search matches words across title, app, workspace and project, in any order. Every word must
match. The tiers are exact, prefix, word-prefix, substring, acronym and fuzzy subsequence.
Each word uses the field with the highest tier times field weight, with title/app winning
weighted ties. Tiers run from 6 to 1; title/app have weight 2 and workspace/project weight 1.
Equal title/app scores prefer title; equal workspace/project scores prefer workspace. Empty Search preserves
the Lens's sort; Search ties use that order. Search is remembered per named Lens and selected
on reopening in Search. In normal mode it waits for `/`. `--search` overrides it, and is
applied at once in either state: a grid opened with `--search` starts in normal mode over its
matches. A strip ignores it until `/`.

A leading `=` makes the whole Search box a Nickel function body, with `w`, `ctx` and `filters`
bound. For example, `= filters.floating w ctx`. Evaluation starts after 150 ms without typing.
An error keeps the last good rows and shows its first line with an amber border. The display
deadline is 50 ms; the helper deadline is 100 ms.

Enter focuses the selection, shift-enter and alt-enter Summon it, cmd-w closes it, and cmd-1
through cmd-9 move it to that workspace of the window's own project. Custom keys merge over these
defaults and run against the selected window. Configured Command shortcuts take priority over
Search field editing, including Cut and Close. Tab toggles marks; commands act on marked windows
in mark order, while focus acts only on the selection. Escape, Tab and the four arrow keys,
including their modifier variants, are reserved for Lens navigation and rejected in `keys`
at load. In every Presentation, moving the pointer over a Tile selects it after it moves
more than one point from its anchor (Euclidean distance). First presentation, a keyboard or
wheel step, Search reselection and a miniature page turn anchor the pointer again. A Tile
sliding under a resting pointer cannot replace the default or keyboard selection. Leaving
the panel keeps the last selection. The strip commits the last input, key or pointer, on
release; the grid stays open until Return or a click. Click selects
the Tile under the pointer and runs enter; modifier-click runs the corresponding modifier-enter
command. A click in a strip or grid gap does nothing. `lens --presentation list`
keeps selection, marks, Search and the snapshot of eligible windows. Reloading config preserves
an open Lens's entries and actions until it closes.

Focus restores a minimized row on its origin workspace and focuses it there, recreating that
workspace if cleanup removed it. A row with no known origin uses the current workspace.
Summon restores it on the current workspace. Workspace moves restore minimized and hidden
rows before moving them, keeping floating windows floating. Close acts without restoration.
For opted-in popup rows, Focus raises the native window and Close closes it; Summon and
workspace moves fail with a diagnostic and leave the popup tree intact.

The shipped `search` Lens uses the Lens contract's defaults. Users can override its sort and
Presentation by merging over `winmux/defaults.ncl`, for example:

```nickel
let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  lenses.search = { sort = ['title], presentation = 'strip },
}) | W.Config
```

The shipped `floating` Lens uses `filters.floating` (`fun w ctx => w.class == 'floating`),
with the list Presentation, MRU sort and empty `popups`. It finds floating windows on every
workspace; Enter focuses one there and shift-enter Summons it to the current workspace.
The `window` binding mode reaches it with `f`. Both the named Filter and Lens settings can be overridden by a config.

An app whose bundle declares `LSUIElement` floats by default, even when its live activation
policy is regular. Filters read that stable identity as `w.app.accessory` and the live policy
as `w.app.activationPolicy`. Popup-classified windows use `accessory-popup` while the live
policy is accessory, and `app-popup` otherwise. A window with no close button is a popup
under accessory policy; a standard dialog under regular policy remains reachable as floating.
To list an Accessory app's popups alongside its floating windows, configure:

```nickel
let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  lenses.accessory = {
    popups = ['accessory-popup],
    filter = fun w ctx => w.app.accessory && (w.class == 'floating || w.class == 'accessory-popup),
  },
}) | W.Config
```

Popup Focus raises the native window. Summon refuses with `Cannot Summon a popup window`
and moves nothing, because a popup has no workspace.


## The Hold

A Lens session reads keys in exactly one state: the **Hold**, **normal**, or **Search**.
A Trigger with modifiers starts one Hold. CLI openings and the modifier-free Lens
letters in the `window` binding mode have none. Changing Presentation keeps the input state.

During a Hold, the Lens reads keys in this order:

1. Return uses its Enter binding with the Trigger's own modifiers removed, before matching
   the pressed chord. Return during an Option or Option-Shift Hold focuses; extra
   Shift on an Option Hold Summons. Other bound Lens chords win as pressed: `cmd-w` closes the selected
   window and keeps the Hold, and `cmd-g` changes grouping in a list or grid.
2. The Trigger's own key steps, with Shift reversing. Tab and backtick with the
   invoking modifiers keep their existing stepping behavior; the other Trigger's
   key is consumed without stepping. In a held list, Tab also steps through the
   matches (Shift-Tab reverses), including during Option-slash’s Hold.
3. Arrows move and Escape dismisses, with the Hold's modifiers removed.
4. The first unbound letter, or `/`, ends the Hold. Shift with a letter still counts.
   The letter is identified by what the current keyboard layout types with the
   Hold's modifiers removed. It is read in the Lens's starting state: in normal
   mode `j` moves down and `x` does nothing; in Search it is the first typed letter.
   `/` always starts Search. A strip stays a strip at a normal-mode letter; `/`
   converts it to a list and keeps its selected window. A strip configured to start
   in Search converts at the first letter and types that letter.
5. A chord with a foreign Command, Control or Option modifier belongs to its global
   binding and dismisses the Lens before that binding runs.

Backspace, digits, Space, other punctuation and function keys do nothing during a
Hold. They do not end it. Releasing its invoking Command, Control and Option
modifiers (or Shift for a Shift-only chord) ends it too. Release commits a strip;
other Presentations remain open. **A Hold ended by a key never commits on release**,
including a release received while opening. One session never starts a second Hold.
The strip's display deadline remains 100 ms.

In normal mode, a plain key or chord bound in Lens `keys` wins. Otherwise `h`, `j`,
`k`, `l` move as left, down, up and right arrows in that Presentation. In a list
`h` and `l` do nothing; in a one-row strip `j` and `k` cycle as down and up do.
Arrows move, `/` enters Search, Return runs its binding, Escape dismisses, and Tab
marks as before. All other plain keys are consumed without typing. An unbound
Command, Control or Option chord belongs to its global binding. After a letter
ends the Hold, repeating the Trigger's chord with its modifiers still down toggles
the same Lens closed in every Presentation, named or ad hoc; it does not step or start
another Hold. An ad-hoc Lens is the same when its Filter text, resolved opening
settings (including Presentation overrides) and explicit `--search` are equal.

In Search the field editor owns letters, Backspace and clipboard shortcuts,
including Command-A and Command-V while the Trigger's modifiers are still down.
A bound Lens chord still wins. Plain letter bindings are typed in Search.
Up/down move selection; left/right navigate Tiles in grid and miniatures and move
the caret in a list. Return commits. Escape returns to normal mode with the text
and matches kept; `j` then moves among those matches. A second Escape dismisses.
This also applies to a Lens that opened in Search.

The Search row is muted and shows `/` during a Hold and in normal mode. The panel
owns the keyboard in those states; clicking that row enters Search and gives the
keyboard to its field. A strip has no Search row. Letters arriving in Search
before its editor is ready are retained in order. Queued opening keys use the same
state decisions: the first letter ends the Hold and later Carbon presses are decided
in the resulting state. Only the Lens's own keys are queued. Other Carbon bindings
run immediately; they dismiss an opening Lens exactly where they would dismiss
that Presentation once shown. No global binding is replayed later.

Known limit: before the panel becomes key, an unregistered key goes to the app
in front and the Lens never sees it. This covers opening (including dispatch and
Filter evaluation) and the strip's 100 ms before it is drawn. Only chords WinMux
has registered with Carbon can reach an opening Lens. There is no keyDown monitor
capture or replay of other apps' typing.

### `starts-in`

`starts-in = 'normal` or `'search` is a Lens setting, also accepted in
`when.default`. It has no Nickel default. At session opening, Swift uses the
explicit setting, otherwise Search for a list and normal for a strip, grid or
miniatures. The opening Presentation decides: `lens recent --presentation list`
starts in Search. There is no CLI flag, and converting an open Lens keeps its state.
A Lens with a Hold enters its starting state when the Hold ends.
`list-lenses --json` reports the configured value, or `null` when it is omitted.

A Lens that starts in Search shows and applies its remembered Search from opening,
including during a Hold. Stepping during the Hold moves among those matches;
release enters Search with its text selected and the selection unchanged. The first
letter replaces that text. Opening in normal mode leaves it inactive and unapplied.
At `/` it appears selected and is applied, and the first letter replaces it.
Applying remembered Search keeps the selected window if it matches, and selects
the best match otherwise. A strip has no Search row, so it never opens filtered by a
remembered Search, whatever its `starts-in`: the Search is applied when the strip
becomes a list. A Search-starting strip also keeps a matching selected
window through conversion at the Hold-ending letter, using the typed Search.
Leaving Search with Escape preserves its matches.

A binding mode's Carbon keys take priority as before. A Lens opened from the CLI
with the `window` binding mode on receives none of `h`, `j`, `k`, `l`: they run the
mode's focus commands. The mode's own Lens letters run `mode main` before opening
so this does not affect Lenses opened from that mode.

[Session key records](lens-opening-traces.md#session-keys) show each key's input
state, the key ending the Hold, focus and the final Search/selection.


## Strip and the system switcher

`recent` is a strip of every eligible window in Global MRU order. `app-windows` uses the same
Presentation and sort with `filters.same-app`: the window's bundle id must equal the focused
app's bundle id. With no focused app it matches nothing. Both omit popup classes.
They use the same Lens session, Filter evaluation and thumbnail cache as the list and miniatures.

With the [Cmd-Tab opt-in](default-config.md#opt-in-to-cmd-tab), hold cmd and press Tab to select the previous window: the second entry when the first is
focused, otherwise the first. Further Tab presses cycle forward, including presses received
while the Filter is still opening. Releasing cmd while it is still opening settles the selection:
the commit runs as soon as the Lens is ready, and a press after that release is ignored.
Shift-Tab cycles backward. Left and right cycle in ranked order with wrap, across rows.
In one row, up cycles backward and down forward; in a wrapped strip they move to the
nearest Tile in the row above or below and stop at the top and bottom.
With that opt-in, an initial cmd-shift-tab selects
the last entry; releasing Shift alone does not commit. The opt-in's Cmd-backtick cycles the focused app's
windows, with Shift reversing it. Backtick does nothing inside `recent`, and Tab does nothing
inside `app-windows`.

The strip waits 100 ms before drawing. A faster release, or `winmux lens recent` with no
modifiers held, focuses the previous window immediately. On a held invocation, releasing all
invoking Command, Control and Option modifiers runs the selection's enter binding. Shift is
never a committing modifier. Release closes the strip even if its Enter binding has no commands.
Releasing cmd with Option held runs `alt-enter`, whose default
is `summon`; Shift affects cycling and does not change that release action. Summon hints appear
only for a selection on another workspace. Escape cancels without changing focus.

Every match is visible. The shipped strips use `grid.tile-size = 'same-height` and picture Tiles. A config Lens
without a size setting uses the contract default `real`. The strip
ignores sections and `grid.sections-arrangement`. Its row height grows up to 190 scaled points.
It first fits one row at or above the readable floor: 48 scaled points for picture Tiles at
`same-height` or `equal`, 88 for card and text Tiles and for pictures at `real`, which scales
small windows well below the row. Otherwise it uses the fewest
readable rows and the largest height those rows allow. Cards retain the grid's title-width
floor, so they wrap sooner than pictures. When readable rows cannot fit vertically, Tiles
shrink until every match fits, with title width and chrome yielding below 36 scaled points.
There is no overflow count, scrolling or paging. Rows wrap greedily in ranked order and
are centred; stepping and hovering keep the same cached frames. Text Tiles use the grid's
330 by 46 points at a visible size of 1920 by 1080 and wrap by the same rule.
The strip retains its own padding, footer and empty-panel size. Entries show app icons
and titles before capture, then reuse live or Frozen thumbnails and the Lens's
`frozen-thumbnail` and Accessory settings. Every non-Frozen picture refreshes every 500 ms.
Accessory `enlarged` pictures use the full row height; `actual-size` uses the window's
monitor-height fraction with a 28-point picture floor, in every size mode. The grid ignores
this Accessory size setting. Hidden apps
and minimized windows remain eligible. Removing an earlier entry keeps the selected window; removing
the selection chooses its surviving successor, or the last entry. Hover selects with the
one-point movement rule used by every Presentation; click selects the Tile under the pointer
and runs the
corresponding Enter action immediately. During a Hold it subtracts the invoking
modifiers as release does: Cmd-click focuses and cmd-Option-click Summons. After a
key ends the Hold, click modifiers mean themselves.

An unbound letter ends the Hold and keeps the strip modal in normal mode; `j` and
`k` move as down and up. `/` converts the same session to a list, preserving the
selected window, and enters Search. With `starts-in = 'search`, a letter converts
and types into Search instead. Later modifier release never commits either case.

The scroll wheel steps selection in the strip and the grid while the pointer is over the
panel. A line-based wheel steps one Tile per event. A trackpad gesture steps once after
four accumulated vertical points, only when vertical movement exceeds horizontal movement;
its remaining events and momentum do not step again. Precise wheel events without gesture
phases step once per burst, with a new burst after 200 ms of quiet. The direction that pages miniatures
forward also steps forward. The strip wraps as Tab does; the grid follows entry order and
stops at either end. A wheel step re-arms the resting-pointer rule. The list scrolls its rows,
and miniatures keeps its existing page turns. Scroll outside the panel is not handled.

A Lens `keys` binding wins first: cmd-w closes the selected window while the Hold
and strip stay open. You can also open `winmux lens recent --presentation list --tile text`
explicitly for the text list drawn by the window mode's `r`; without `--tile text`, it draws the Lens's picture rows. A foreign modifier chord during a Hold closes the Lens and runs its
global binding, whether drawn or still opening. After the Hold, unbound modifier
chords again belong to global bindings; repeating its Trigger toggles the Lens closed.

An ad-hoc binding can use the strip:

```nickel
let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  mode.main.binding.alt-r = "lens --filter same-app --presentation strip",
}) | W.Config
```

When the active mode listens to cmd-tab or cmd-shift-tab, WinMux disables the enabled matching
native symbolic hotkeys for both directions. It reads the live table rather than assuming ids,
and leaves native cmd-backtick enabled. Removing the bindings, changing to a mode without them,
`enable off` and normal termination restore only ids WinMux took. A pre-existing disabled id stays
disabled. An id whose chord changed, or an enabled id whose chord is no longer wanted, is left alone
and removed from the marker. An id re-enabled while its chord is still wanted is taken again
in the same pass, with ownership persisted before disabling it. Candidate ids are cached after
the first active scan and rescanned during repair; a scan that finds none is repeated on the next
reconcile. An id that cannot be read stays in the marker until it can be restored. An idle
reconcile does no table work, and marker writes happen only when ownership changes. Repair reports failures from both restoration
and retaking; a later successful operation clears them. Launch, wake and unlock repair and
reconcile the current registrations.

`winmux doctor` prints the held symbolic-hotkey ids, recovery marker ids and reconciliation errors.
Carbon registration failures are logged and failed registrations do not claim the native chord.
Another cmd-tab app can receive the same chord and draw a second switcher; WinMux cannot reliably
identify it or offer a winner-selection prompt. Disable one owner's binding if both appear.

The private macOS API changes the session's live state, not System Settings. Before disabling an
id, WinMux records its original chord in a UserDefaults recovery marker. Quit, SIGTERM, SIGINT,
SIGHUP, an uncaught Objective-C exception and the exit hook restore owned ids. Signal sources
restore off the main queue before normal cleanup, with a two-second exit deadline if cleanup
stalls. Once WinMux has restored the chords to exit, it does not take them again. Their no-op signal dispositions reset to defaults on exec. A hard kill cannot
run these hooks: native cmd-tab remains disabled until WinMux launches again and repairs the
marker. Quit that recovered instance to return the native chord. The debug executable uses the
`WinMuxApp` defaults domain; an app bundle uses its own bundle domain. An unrelated installed
upstream build cannot repair this build's marker.


## Sections and the grouping control

Every list and grid Lens draws workspace sections by default, including `search`, `floating`
and a strip converted to a list. Set `sections = 'none` for an unlabelled run.

| `sections` | Order and label |
| --- | --- |
| `workspace` (default) | Workspace order, with the focused workspace first; workspace display names. |
| `project` | Project order, with the focused project first; project display names. |
| `monitor` | Monitor order, with the focused monitor first; monitor names. |
| `app` | Each app's first occurrence in the Lens's ranked results; app names. |
| `none` | One unlabelled run in the Lens's ranked order. |

Focus is snapshotted when the Lens opens. Its section is marked `· here`; app sections have
no mark. Empty sections disappear. Windows with no workspace go in a final `No workspace`
section; missing projects and monitors use the corresponding `No project` or `No monitor` label.
Windows of multiple processes with the same bundle identity share an app section; `entries = 'app` still shows one entry per process.
A window that closes while a list or grid is open leaves it, and the selection stays on its window.
With `entries = 'app`, sections group the representatives.

The list draws a 32-point header above each section, inside the scrolling rows. Up and down
walk windows across headers. Search keeps the grouping and selects the strongest match even
when it is in a later section. Marks, actions, hover and the grid's count use this same entry order.

The Search row has a right-aligned `Group` control. Its segments show `none`, `workspace` and
`app`, followed by `project` or `monitor` when the opening's entries span more than one of them.
A grouping set explicitly outside that cycle appears as an extra selected segment. Clicking a
segment preserves the selected window, Search focus and any Hold. The shortcut chip shows
this Lens's first binding to `sections next`, and disappears when there is none.
The grid grows to at least 644 scaled points for the three-segment control, plus 68 per extra
segment; the list also keeps its 760-point minimum.

```sh
winmux lens search --sections app
winmux lens recent --presentation grid --sections app
winmux sections next
winmux sections workspace
```

`--sections` accepts the five values above, needs a Lens name or `--filter`, and changes this
opening only. Miniatures refuses it with exit 2; a strip accepts and ignores it until conversion
to a list. `list-lenses --json` continues to report the configured values.
The `sections` command changes an open list or grid without closing it or emitting `lens-opened` or `lens-closed` subscription
events. With no Lens open it exits 2 with `No Lens is open`; miniatures and strips stay open
and ignore it. A grouping change lasts until this Lens closes. Converting a strip retains it.

The default Lens key `cmd-g = "sections next"` cycles grouping. A value outside the cycle
advances to `none`. Bound chords win during a Hold: `cmd-g` changes grouping in a
list or grid without ending it. A grouping-only key is omitted in strips and
miniatures. A strip stays a strip when `g` ends its Hold; it converts at `/`.
After conversion, `cmd-g` changes grouping, including with Command still down.

## Grid

`winmux lens recent --presentation grid` shows every match at once. The panel is centred on
the focused monitor and fits its contents, up to 90% of the visible width and 88% of its height.
Tiles pack left to right into centred rows with 14-point gaps at 1920 by 1080. The picture row
height starts at 330 scaled points and shrinks until everything fits. There is no paging or
minimum Tile size; at very large counts, title width, type and spacing shrink too.

```nickel
let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  lenses.documents = {
    presentation = 'grid,
    grid = { tile-size = 'real, sections-arrangement = 'flow },
    tile = 'card,
  },
  mode.main.binding.alt-g = "lens documents",
}) | W.Config
```

| `grid.tile-size` | Pictures |
| --- | --- |
| `real` (default) | One scale factor, row height divided by the monitor's visible height, applied to each window's real size. A dialog stays smaller than an editor. |
| `same-height` | A common picture-row height with widths allocated from aspects clamped to 0.6–2.1. |
| `equal` | Equal 1.5:1 picture boxes, with each picture fitted inside its box. |

`real` is the contract default for a config Lens; the two shipped strips override it with `same-height`.

| `grid.sections-arrangement` | Labelled sections |
| --- | --- |
| `flow` (default) | Sections run on in centred rows; a mid-row section starts 30 points beyond the normal gap. Every row reserves header space. |
| `rows` | Each section starts its own left-aligned row, under a full-width header, with six extra points after the section. |
| `columns` | Sections sit side by side, 30 points apart, each wrapping its own Tiles below its header. |

Headers shrink with the chrome and truncate within their available width. No arrangement
pages or has a size floor: a large number of columns becomes small rather than switching layouts.

Pictures keep their own aspect and never grow past their window's real size, including when
selection lifts. Labelled grid rows share a height, including when a window is taller than the monitor. A narrow picture is centred inside the Tile's width allocation. The card's title
floor yields when needed to fit all Tiles. Text Tiles use the same packed rows without pictures;
picture Tiles put the selected title and chips in the footer. The footer also shows app and count.

The grid opens in normal mode unless `starts-in` says Search. Plain letters do not edit Search; use `/`. Search shows only matches, ranks them within their sections, and selects the best-ranked match across all sections. It re-packs them, resizing the panel and Tiles.
Left and right move to the nearest Tile along the row, crossing section boundaries. In columns, a neighbouring Tile with an overlapping vertical span is used when that row is absent. Up and down use the nearest row and horizontal centre; columns prefer a Tile below or above in the same column. Arrows work with no Hold too, and a press at an edge keeps the selection. Left and right therefore navigate Tiles instead of moving the Search caret.
Tab marks, Enter focuses, shift-enter and alt-enter Summon, cmd-w closes, and cmd-1 through cmd-9
move the selected or marked windows to a workspace. Hover, clicks, custom keys, Frozen looks,
`badges` and `entries = 'app` share the other Presentations' behavior. Summon shows its Tile label
and a screen-space landing outline while the configured modifier is held. Trigger release leaves
the grid open.

`grid` settings resolve through `when.default`. `list-lenses --json` reports a `grid` record on
every Lens. Strips use `grid.tile-size`; on lists and miniatures the block loads and is reported
but has no visual effect. `grid.sections-arrangement` controls labelled sections; `sections = 'none` keeps the original packed layout.
The shipped `recent` and `app-windows` remain strips, now with picture Tiles and `same-height` sizing; `overview` stays miniatures and `search` and `floating` stay lists. Use a config Lens or the CLI override for a grid.

## Overview and miniatures

Option-Shift-O opens the shipped overview directly. `winmux lens overview` opens every workspace
in sidebar order, with tiled windows in their layout positions and floating windows above them. Minimized windows use their retained origin
workspace's tray; hidden-app windows use their container's workspace. Popup windows are omitted,
even when the Lens opts into their classes. A minimized window with no known origin has no tray
and remains reachable through the list Presentation.

Workspaces form centred rows and columns below Search. The arrangement tries every column
count and chooses the one that makes each monitor-shaped workspace widest, with fewer rows
on a tie. Order reads left to right, then top to bottom; a short last row starts at the left.
Four workspaces form two rows of two on both a 16:9 display and an ultrawide display.

`fit` decides only what happens below the readable size of 110 points tall. Above it, both
values use the same largest arrangement on one page. Below it, `page` keeps the readable
floor and lays out every page at the full page's size; `shrink` keeps all workspaces on one page.

A window tab group whose tabs are all windows fans out inside its shared frame; with window tabs off, a group keeps its accordion positions. The active tab is in front at the group's origin;
other tabs follow their group order, offset right and down behind it. The offset scales from
16 points per 820-point workspace and shrinks when the total fan would exceed a quarter of
the group's smaller side. Every tab has a selectable edge and uses its cached picture or app
icon. Standalone windows, floating windows and tray entries keep their existing positions. The fan is drawn from the active tab's frame, below the group's tab bar, and fans only the tabs the Lens draws.

Each window keeps its last good thumbnail. Parking, focus loss and minimize request a capture,
with an 800 ms per-window throttle and at most two captures in flight. Hidden apps retain their
last frame; a window with no frame shows its app icon. Inactive native-fullscreen windows use the
same fallback. Opening draws the cache immediately; current-workspace windows on the visible
page refresh every 500 ms. Closing cancels queued Lens refreshes. Capture needs an existing Screen
Recording grant; background capture does not request one.

```nickel
let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  lenses.overview = {
    frozen-thumbnail = 'dimmed,
    accessory-window = 'enlarged,
    summon-hints = ['label, 'landing-spot],
    miniatures = {
      fit = 'page,
      current-workspace = 'highlight,
      arrow-keys = 'nearest,
      backdrop = { darkness = 0.6, blur = true },
    },
  },
}) | W.Config
```

The settings resolve through `when.default` too. `list-lenses --json` reports the resolved
`miniatures` record and shared look settings.

| Setting | Values and behavior |
| --- | --- |
| `miniatures.fit` | Below the 110-point readable floor, `page` keeps a fixed cell size and scrolling turns pages; `shrink` fits all workspaces. |
| `miniatures.current-workspace` | `plain`, `highlight` (default), `enlarge`, or `hide`. |
| `miniatures.arrow-keys` | `nearest` (default) uses geometry; `by-workspace` uses left/right within a workspace and up/down between workspaces. |
| `miniatures.backdrop` | `darkness` from 0 to 0.95 (default 0.6); `blur` defaults to true. The panel remains non-opaque. |
| `frozen-thumbnail` | `plain`, `dimmed` (default), `age-badge`, or `pause-badge`. Live thumbnails are unmarked. |
| `accessory-window` | `enlarged` (default) makes small Accessory windows readable; `actual-size` keeps their scale. Both show a dashed outline and a menu-bar app tag. |
| `summon-hints` | Any of `label`, `landing-spot`, `target-workspace`; defaults to the first two. Shown while the modifier of a configured Summon binding is held. |

Miniatures keeps its own workspace arrangement and window entries; its contract rejects explicit
`tile`, `sections`, `entries` and `sort`. `current-workspace = 'hide` cannot be combined with a
`landing-spot` hint. Backdrop darkness above 0.95 fails config checking.

`by-workspace` up/down selects the previous/next workspace in reading order, even when the next cell is to the right.

Search dims non-matches at their fixed positions and selects the best match. Arrows navigate only
matches; Tab marks and Enter/shift-enter keep the same Focus/Summon actions as the list. Only the
selected window's title appears, under its workspace. The landing hint uses Column Policy's
placement on a workspace with Columns, and the tree's append geometry otherwise.

`winmux lens floating --presentation miniatures` ignores that Lens's list grouping and sorting.
`winmux lens --presentation list` keeps the open session's Search, marks and selection. The `window` binding mode reaches `overview` with `o`.

## Leaving the windowing mode

The shipped windowing bindings run `mode main` before their Lens command: `o` opens `overview`, `f` opens `floating`, `s` opens `search`, `r` opens `recent --presentation list --tile text`, and `a` opens `app-windows --presentation list --tile text`. Escape and Option-semicolon run only `mode main`. The HUD is hidden before a Lens opens. A failed Lens command therefore leaves the shipped leader at `main` too. A standalone `lens` command does not change a user's active mode, even when that mode is named `lens`.

Lens subscription events describe visible panels. A strip released before its 100 ms display delay emits neither `lens-opened` nor `lens-closed`. A presented strip emits one pair; Search and handoff to the list keep that pair. List, grid and miniatures panels appear immediately. See [subscription events](events.md).
