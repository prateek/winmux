# Lenses and Search

A Lens combines a Filter, sort order, a Presentation and commands for its selected window.
Import `winmux/defaults.ncl` to get `search`, `floating`, `overview`, `recent` and `app-windows`.
Alt-slash opens `search`; alt-semicolon enters the `lens` binding mode for `overview`, `floating`, `search` and the list Presentation of `recent`. Cmd-tab and cmd-shift-tab open `recent`, and cmd-backtick opens `app-windows`. See [default Triggers](default-config.md). `palette` is an alias for
`lens search`; without that Lens both commands fail.

```nickel
let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  filters.tiled = fun w ctx => w.class == 'tiled,
  lenses.work = {
    filter = filters.tiled,
    presentation = 'list,
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
profile is `default`; other `when` records load but do not apply. `strip` draws a centred row; `miniatures` draws workspace copies. `grid` is rejected.

```sh
winmux list-lenses --json
winmux lens search --search 'release notes'
winmux lens --filter "w.class == 'floating" --sort mru,title
printf '%s' 'w.app.name == "Editor"' | winmux lens --filter -
winmux list-windows --lens work --json
winmux list-windows --search 'release notes' --workspace focused --json
winmux summon --window-id 42
```

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
on reopening. `--search` overrides it.

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
at load. Pointer movement over a row selects it; a stationary pointer cannot replace the
default or keyboard selection. Click runs enter, and
modifier-click runs the corresponding modifier-enter command. `lens --presentation list`
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
The `lens` binding mode reaches it with `f`. Both the named Filter and Lens settings can be overridden by a config.

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


## Strip and the system switcher

`recent` is a strip of every eligible window in Global MRU order. `app-windows` uses the same
Presentation and sort with `filters.same-app`: the window's bundle id must equal the focused
app's bundle id. With no focused app it matches nothing. Both omit popup classes.
They use the same Lens session, Filter evaluation and thumbnail cache as the list and miniatures.

Hold cmd and press Tab to select the previous window: the second entry when the first is
focused, otherwise the first. Further Tab presses cycle forward, including presses received
while the Filter is still opening. Releasing cmd while it is still opening settles the selection:
the commit runs as soon as the Lens is ready, and a press after that release is ignored.
Shift-Tab cycles backward, and the arrows cycle with wrap.
An initial cmd-shift-tab selects
the last entry; releasing Shift alone does not commit. Cmd-backtick cycles the focused app's
windows, with Shift reversing it. Backtick does nothing inside `recent`, and Tab does nothing
inside `app-windows`.

The strip waits 100 ms before drawing. A faster release, or `winmux lens recent` with no
modifiers held, focuses the previous window immediately. On a held invocation, releasing all
invoking Command, Control and Option modifiers runs the selection's enter binding. Shift is
never a committing modifier. Release closes the strip even if its Enter binding has no commands.
Releasing cmd with Option held runs `alt-enter`, whose default
is `summon`; Shift affects cycling and does not change that release action. Summon hints appear
only for a selection on another workspace. Escape cancels without changing focus.

Nine entries fit at most, with fewer on a narrow display. Selection scrolls the row; each end
shows `+N` for its hidden entries. Entries show app icons and titles before capture, then reuse
live or Frozen thumbnails and the Lens's `frozen-thumbnail` and Accessory settings. Hidden apps
and minimized windows remain eligible. Removing an earlier entry keeps the selected window; removing
the selection chooses its surviving successor, or the last entry. Hover selects; click runs the
corresponding Enter action immediately, subtracting the invoking modifiers as release does.
Cmd-click focuses and cmd-Option-click Summons.

An unbound letter with the invoking modifiers (Shift may also be held), or with none, converts
the same session to a list, puts the letter in Search and preserves the selection when it remains
a match. A Lens `keys` binding wins first: cmd-w closes the selected window while the strip stays
open. Modifier release no longer commits after conversion to a list. You can also open
`winmux lens recent --presentation list` explicitly. A global binding whose modifiers are not the
strip's, Tab and backtick bindings included, closes the strip and runs normally, whether the strip
is drawn or still opening; releasing the invoking modifiers afterward cannot undo that binding.

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


## Overview and miniatures

`winmux lens overview` opens every workspace in sidebar order, with tiled windows in their
layout positions and floating windows above them. Minimized windows use their retained origin
workspace's tray; hidden-app windows use their container's workspace. Popup windows are omitted,
even when the Lens opts into their classes. A minimized window with no known origin has no tray
and remains reachable through the list Presentation.

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
| `miniatures.fit` | `page` keeps a readable workspace size and scrolling turns pages; `shrink` fits all workspaces. |
| `miniatures.current-workspace` | `plain`, `highlight` (default), `enlarge`, or `hide`. |
| `miniatures.arrow-keys` | `nearest` (default) uses geometry; `by-workspace` uses left/right within a workspace and up/down between workspaces. |
| `miniatures.backdrop` | `darkness` from 0 to 0.95 (default 0.6); `blur` defaults to true. The panel remains non-opaque. |
| `frozen-thumbnail` | `plain`, `dimmed` (default), `age-badge`, or `pause-badge`. Live thumbnails are unmarked. |
| `accessory-window` | `enlarged` (default) makes small Accessory windows readable; `actual-size` keeps their scale. Both show a dashed outline and a menu-bar app tag. |
| `summon-hints` | Any of `label`, `landing-spot`, `target-workspace`; defaults to the first two. Shown while the modifier of a configured Summon binding is held. |

Miniatures always uses workspace sections and window entries; its contract rejects explicit
`sections`, `entries` and `sort`. `current-workspace = 'hide` cannot be combined with a
`landing-spot` hint. Backdrop darkness above 0.95 fails config checking.

Search dims non-matches at their fixed positions and selects the best match. Arrows navigate only
matches; Tab marks and Enter/shift-enter keep the same Focus/Summon actions as the list. Only the
selected window's title appears, under its workspace. The landing hint uses Column Policy's
placement on a workspace with Columns, and the tree's append geometry otherwise.

`winmux lens floating --presentation miniatures` ignores that Lens's list grouping and sorting.
`winmux lens --presentation list` keeps the open session's Search, marks and selection. The `lens` binding mode reaches `overview` with `o`.
