# The `'grid` Presentation: every match at once, sized to fit

Part of {{UMBRELLA}}.

## What to build

`'miniatures` draws each workspace as a small copy of itself, which answers "where is it". The grid answers "which one": every match at once as Tiles packed into rows, as large as the monitor allows, for sets of windows whose positions mean nothing. One app's windows across workspaces, the floating windows, the results of a Search.

Today a config with `presentation = 'grid` is rejected at load. This issue builds it and removes the rejection.

## Decisions

- **Packed rows.** Tiles are placed left to right and wrap. Each row is centred. The panel is as large as its contents, up to most of the monitor, and is centred on the monitor.
- **Sized to fit.** The row height is the largest at which every Tile fits in the panel. Three windows are large; fourteen fill three rows; forty are small.
- **Tiles shrink and nothing is cut off.** There is no floor and no paging in this issue. Paging is a later issue.
- **Tile size**, set as `grid.tile-size`:
  - `'real`, the default: every picture is scaled by the same factor, so a dialog stays smaller than an editor.
  - `'same-height`: every picture has the row height and its own width.
  - `'equal`: every Tile is one box and the picture is fitted inside it.
- **A picture is never drawn larger than its window.**
- **Its own block in the config.** Grid settings live under `grid` in the Lens, as `'miniatures` settings live under `miniatures`. `grid` on a Lens with another Presentation is ignored, as `miniatures` is.
- **Everything shared is shared.** Search, marks, Summon and its hints, the Lens's `keys`, Frozen thumbnails and `entries` work in the grid as in the other Presentations, through the Tile.
- **Arrow keys move to the nearest Tile** in the pressed direction.
- **The look is the prototype's**: [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html), Presentation set to Grid.

## Not in this issue

- Sections. The grid in this issue is one ungrouped run of Tiles; **Sections, and a control to change the grouping** adds them.
- Paging, and collapsing Tiles to text when there are too many.
- Windows moving from their places into the grid when it opens.
- A shipped Lens that uses the grid. **Shipped Lenses for the grid, and the docs** adds them.

## Depends on

- **The Tile: one drawing of an entry, shared by every Presentation**.

## Defaults chosen for you

- **The limits.** The panel is at most 90% of the monitor's width and 88% of its height. The row height starts near 30% of the monitor's height and steps down until everything fits. A card is never narrower than its title needs to stay readable; the prototype's rule is the starting point.
- **Opening.** The panel fades and scales in over about a tenth of a second. Nothing flies.
- **The thumbnail cache** caps a thumbnail's width (`ThumbnailCache.swift`). With few windows a Tile can be wider than the cap. Raise the cap for the Tiles that need it or accept the softness, and say which in the pull request.
- **The command line.** `winmux lens --presentation grid` is accepted wherever `list`, `strip` and `miniatures` are.
- **The layout is a pure function** from Tile sizes and a monitor size to frames, tested without a window server, as `StripLayout` and `MiniatureLayout` are.

## Done when

- [ ] A Lens with `presentation = 'grid` loads, opens and draws every match.
- [ ] With three windows the Tiles are large; with the staged desk's fourteen they fill the panel in rows; with forty every Tile is on screen.
- [ ] `grid.tile-size` takes its three values, and `'real` shows a dialog smaller than an editor.
- [ ] Search narrows the grid and it re-sizes to the matches; marks, `close`, `focus`, Summon and the workspace keys act on the selection.
- [ ] Arrow keys reach every Tile.
- [ ] Layout tests cover one Tile, a full row, a wrap, and forty Tiles.
- [ ] The pull request shows the grid on the staged desk beside the prototype at the same settings.

## Sources

- [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html)
- [The grid prototype ticket](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/08-prototype-grid-presentation.md), which chose miniatures for `overview` and left the grid's look open.
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
