# The Tile: one drawing of an entry, shared by every Presentation

Part of {{UMBRELLA}}.

## What to build

Before this issue, each Presentation drew its entries its own way. The list had a text row (`SwitcherPaletteRow` in `Sources/AppBundle/ui/hud/SwitcherPalette.swift`). The strip and `'miniatures` shared `MiniatureEntryView` (`Sources/AppBundle/ui/hud/MiniaturesView.swift`), and the strip wrapped it in a fixed 148 by 92 box, so a narrow window leaves half the box empty. A change in one drawing did not reach the others.

This issue makes one **Tile**: the drawing of one Lens entry. Every Presentation lays out Tiles and draws nothing of its own inside them. After it, the strip, the list and `'miniatures` look like [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html), and the grid has a Tile to lay out.

## Decisions

- **A Tile has a kind**, set per Lens as `tile`:
  - `'card`: app icon and title above the picture.
  - `'picture`: the picture alone, with the app icon in its corner. The title of the selected Tile shows in the Presentation's footer.
  - `'text`: icon, title and app name on one line, no picture.
- **Defaults by Presentation.** `'strip` and `'grid` default to `'card`. `'list` defaults to `'text`; with `'card` or `'picture` a list row gains a small picture at its left. `'miniatures` always draws pictures and rejects `tile` at load, as it rejects `sections`, `entries` and `sort`.
- **The picture keeps the window's shape.** A Tile's picture has the aspect ratio of its window. A strip Tile's allocated width clamps aspect to 0.3–3.6. An extreme picture is centred at its real shape, with no fill or outline at the allocated size. The opening aspect comes from the same rectangle as capture and stays fixed until dismissal.
- **Badges.** A Tile shows, beside its title: the workspace label when the window is not on the focused workspace (its number, otherwise the sidebar display name truncated after twelve characters with an ellipsis), and `floating`, `minimized` or `hidden` when the window is. `badges = false` on a Lens turns them off. Picture-only strip chips follow the selected title in the footer; miniatures puts them after the selected title under its workspace cell, omitting the workspace label there. Pictures have no state or workspace chips over them. The Frozen thumbnail look (`frozen-thumbnail`) and the Accessory treatment (`accessory-window`) move onto the Tile unchanged.
- **The selected Tile lifts.** It scales up slightly and gains a thin accent ring and a shadow; its title turns from secondary to primary weight. In a text row the selection is a tinted plate with no scale. Miniatures uses a four-point ring and shadow without scale or raised draw order, preserving floating windows above tiled ones. This replaces the strip's tinted cell and the miniature's thick border.
- **Marks and the Summon label** are parts of the Tile. All list kinds put them and the Accessory tag at the trailing end of the line; strip Tiles and miniatures retain picture adornments, with the card mark in its bar.
- **A Tile draws an entry, not a window.** Today every entry is a window or an app. The Tile takes what it draws (icon, title, picture, badges) from the entry, so that a Tab can be an entry later without a second drawing.
- **The look is the prototype's.** Sizes, spacing, radii and type are read from [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html) at 1920 by 1080 and scaled by the smaller of visible width / 1920 and visible height / 1080. The list panel is 760 wide at that scale, with scaled Search type and height, and its rows fit up to 82% of visible height less the header; position remains a quarter of the way down. Where SwiftUI cannot match a value, the builder gets as close as it can and says so.
- **`Tile` is added to `CONTEXT.md`** by the pull request that drafts this issue. Use the word as written.

## Not in this issue

- The `'grid` Presentation, which is **The `'grid` Presentation**.
- Sections, the matched-text highlight, window controls on hover, held hints and peek. Each has its own issue and adds a part to the Tile.
- Any change to which windows a Lens lists, or to the thumbnail cache.

## Depends on

- **Lens state, events and effect lifetimes, with controlled time**. The Tile is built on the session that issue produces.

## Defaults chosen for you

- **The strip's cell.** The strip keeps one row and its nine-entry window for now, with each Tile at one row height and its own width. **The strip as one row of the grid** removes the limit.
- **The contract.** `tile` and `badges` are fields of `LensFields` in `nickel-helper/nickel/winmux/winmux.ncl` and of `LensConfig`. `winmux list-lenses --json` reports them.
- **Per invocation.** `winmux lens <name> --tile <kind>` overrides the Lens's kind for that opening, beside `--presentation`.
- **A window with no thumbnail yet** shows its app icon at picture size, as today.

## Done when

- [x] The strip, the list and `'miniatures` draw every entry through one Tile view; `SwitcherPaletteRow` and the strip's own cell are gone.
- [x] In the strip on the staged desk, no Tile has dead space beside its picture: a narrow window's Tile is narrow.
- [x] `tile = 'text` on a strip and `tile = 'card` on a list both load and draw as the prototype shows.
- [x] `tile` on a `'miniatures` Lens fails at load with a message naming the field.
- [x] A window on another workspace shows its workspace label; a floating window shows `floating`; `badges = false` removes both.
- [x] Marks, the Summon label, the Frozen thumbnail looks and the Accessory treatment draw in all three Presentations as they did before.
- [ ] The pull request shows the strip, the list and `overview` on the staged desk beside the prototype at the same settings.

## Implementation notes

The shared drawing is `Sources/AppBundle/ui/hud/TileView.swift`. Its window-free
`TileEntry` is prepared once from the opening snapshot; `TileKind`, `TileBadges`
and `TileMetrics` are pure, tested seams for the grid. Presentations retain
placement, routing, Search, workspace geometry, landing rectangles and footers.
There is no new dependency or change to eligibility or capture scheduling. Tile shape and capture share one frame-selection helper. Picture policy and refresh dispatch live on the session; its owner retains the single refresh task. List requests are bounded to a viewport-sized selection window, and strip layout is one value per render or refresh, without session caching.

No **Default chosen for you** changed.

Decided: workspace geometry uses the sidebar workspace order and reads each
retained origin once, avoiding per-window monitor reads. Tiles reuse this same
opening snapshot for workspace labels rather than rebuilding sidebar ordinals.

Decided: the strip fits the widest contiguous run of at most nine entries at one
stable height, so moving selection cannot resize the row. Its 44-point end
padding reserves the existing hidden-entry counters.

Decided: a `--tile` override needs a named Lens or `--filter`; a no-name
Presentation conversion rejects it rather than silently ignoring it.

Decided: pause and age overlays occupy the picture's bottom-right, leaving the
Summon label at top-right. Their meaning and `ThumbnailAppearance` rules are
unchanged.

Decided: the allowed neutral Accessory fixture checks Accessory styling because
the standing desk's Updater fixture registers as a regular app.

Decided: empty Search returns the original entry order without ranking, and an
empty removed-entry set avoids copying it. Existing order and removal tests
cover these fast paths; entry eligibility is unchanged.

Decided: keep the list's quarter-height top position and cap its height to the
remaining on-screen space as well as the 82% limit, so its last row stays reachable.

Decided: an empty strip reserves a text Tile's width for its “No windows” footer.

Decided: the rich desk's config and text files live under `demo/desk/rich`, preserving
the standing desk's files while allowing one push of `demo/desk` to stage either.
Seed workspaces in order before applying the rich desk's Column rules. Serve owned
pages on localhost and use owned terminal prompt/title text to keep captures public.

Miniatures keeps its adaptive workspace geometry. Native materials, shadow blur,
app icons and live content cannot be pixel-identical to CSS and static pictures.
The strip retains its nine-entry cap and hidden-entry counts rather than prototype
paging, and its Lens name stays out of the footer. The list retains native Search
and scrolling rather than the prototype's group switches and paging footer.

## Sources

- [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html). Open the file in a browser; its switches set the Tile once for every layout.
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
