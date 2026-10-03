# Lenses and Search

A Lens combines a Filter, sort order, a Presentation and commands for its selected window.
Import `winmux/defaults.ncl` to get the unbound `search` and `floating` Lenses. `palette` is an alias for
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
profile is `default`; other `when` records load but do not apply. `strip` and `miniatures`
currently open as lists. `grid` is rejected.

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
(import "winmux/defaults.ncl") & {
  lenses.search = { sort = ['title], presentation = 'strip },
}
```

The shipped `floating` Lens uses `filters.floating` (`fun w ctx => w.class == 'floating`),
with the list Presentation, MRU sort and empty `popups`. It finds floating windows on every
workspace; Enter focuses one there and shift-enter Summons it to the current workspace.
It adds no key binding. Both the named Filter and Lens settings can be overridden by a config.

An app whose bundle declares `LSUIElement` floats by default, even when its live activation
policy is regular. Filters read that stable identity as `w.app.accessory` and the live policy
as `w.app.activationPolicy`. Popup-classified windows use `accessory-popup` while the live
policy is accessory, and `app-popup` otherwise. A window with no close button is a popup
under accessory policy; a standard dialog under regular policy remains reachable as floating.
To list an Accessory app's popups alongside its floating windows, configure:

```nickel
(import "winmux/defaults.ncl") & {
  lenses.accessory = {
    popups = ['accessory-popup],
    filter = fun w ctx => w.app.accessory && (w.class == 'floating || w.class == 'accessory-popup),
  },
}
```

Popup Focus raises the native window. Summon refuses with `Cannot Summon a popup window`
and moves nothing, because a popup has no workspace.
