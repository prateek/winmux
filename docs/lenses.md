# Lenses and Search

A Lens combines a Filter, sort order, a Presentation and commands for its selected window.
Import `winmux/defaults.ncl` to get the unbound `search` Lens. `palette` is an alias for
`lens search`; without that Lens both commands fail.

```nickel
let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  filters.floating = fun w ctx => w.class == 'floating,
  lenses.work = {
    filter = filters.floating,
    presentation = 'list,
    sort = ['mru, 'title],
    keys.cmd-x = "close",
    when.default.enabled = true,
  },
  mode.main.binding.alt-l = "lens work",
}) | W.Config
```

Omitting `filter` matches every candidate. Candidates include minimized windows and windows
of hidden apps. Popup classes are excluded unless listed in `popups`. The one active Display
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
fields are comma-separated. Filters stay in the helper and are omitted from settings JSON.
A failed script Filter prints no stdout. New commands return 0 for success, 1 for an unavailable
server/helper, and 2 for bad usage or a bad Filter.

Search matches words across title, app, workspace and project, in any order. Every word must
match. The tiers are exact, prefix, word-prefix, substring, acronym and fuzzy subsequence.
Title/app matches have twice the weight of workspace/project matches. Empty Search preserves
the Lens's sort; Search ties use that order. Search is remembered per named Lens and selected
on reopening. `--search` overrides it.

A leading `=` makes the whole Search box a Nickel function body, with `w`, `ctx` and `filters`
bound. For example, `= filters.floating w ctx`. Evaluation starts after 150 ms without typing.
An error keeps the last good rows and shows its first line with an amber border. The display
deadline is 50 ms; the helper deadline is 100 ms.

Enter focuses the selection, shift-enter and alt-enter Summon it, cmd-w closes it, and cmd-1
through cmd-9 move it to the corresponding displayed workspace. Custom keys merge over these
defaults and run against the selected window. Tab toggles marks; commands act on marked windows
in mark order, while focus acts only on the selection. Hover selects; click runs enter, and
modifier-click runs the corresponding modifier-enter command. `lens --presentation list`
keeps selection, marks, Search and the snapshot of eligible windows. Reloading config preserves
an open Lens's entries and actions until it closes.
