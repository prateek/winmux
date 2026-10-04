# The Tile: one drawing of an entry, shared by every Presentation

Part of {{UMBRELLA}}.

## What to build

Each Presentation draws its entries its own way today. The list has a text row (`SwitcherPaletteRow` in `Sources/AppBundle/ui/hud/SwitcherPalette.swift`). The strip and `'miniatures` share `MiniatureEntryView` (`Sources/AppBundle/ui/hud/MiniaturesView.swift`), and the strip wraps it in a fixed 148 by 92 box, so a narrow window leaves half the box empty. Nothing drawn in one place carries to the others.

This issue makes one **Tile**: the drawing of one Lens entry. Every Presentation lays out Tiles and draws nothing of its own inside them. After it, the strip, the list and `'miniatures` look like [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html), and the grid has a Tile to lay out.

## Decisions

- **A Tile has a kind**, set per Lens as `tile`:
  - `'card`: app icon and title above the picture.
  - `'picture`: the picture alone, with the app icon in its corner. The title of the selected Tile shows in the Presentation's footer.
  - `'text`: icon, title and app name on one line, no picture.
- **Defaults by Presentation.** `'strip` and `'grid` default to `'card`. `'list` defaults to `'text`; with `'card` or `'picture` a list row gains a small picture at its left. `'miniatures` always draws pictures and rejects `tile` at load, as it rejects `sections`, `entries` and `sort`.
- **The picture keeps the window's shape.** A Tile's picture has the aspect ratio of its window. No Tile letterboxes a picture inside a fixed box.
- **Badges.** A Tile shows, beside its title: the workspace number when the window is not on the focused workspace, and `floating`, `minimized` or `hidden` when the window is. `badges = false` on a Lens turns them off. The Frozen thumbnail look (`frozen-thumbnail`) and the Accessory treatment (`accessory-window`) move onto the Tile unchanged.
- **The selected Tile lifts.** It scales up slightly and gains a thin accent ring and a shadow; its title turns from secondary to primary weight. In a text row the selection is a tinted plate with no scale. This replaces the strip's tinted cell and the miniature's thick border.
- **Marks and the Summon label** are parts of the Tile, drawn the same in every Presentation.
- **A Tile draws an entry, not a window.** Today every entry is a window or an app. The Tile takes what it draws (icon, title, picture, badges) from the entry, so that a Tab can be an entry later without a second drawing.
- **The look is the prototype's.** Sizes, spacing, radii and type are read from [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html) at 1920 by 1080 and scaled to the monitor. Where SwiftUI cannot match a value, the builder gets as close as it can and says so.
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

- [ ] The strip, the list and `'miniatures` draw every entry through one Tile view; `SwitcherPaletteRow` and the strip's own cell are gone.
- [ ] In the strip on the staged desk, no Tile has dead space beside its picture: a narrow window's Tile is narrow.
- [ ] `tile = 'text` on a strip and `tile = 'card` on a list both load and draw as the prototype shows.
- [ ] `tile` on a `'miniatures` Lens fails at load with a message naming the field.
- [ ] A window on another workspace shows its workspace number; a floating window shows `floating`; `badges = false` removes both.
- [ ] Marks, the Summon label, the Frozen thumbnail looks and the Accessory treatment draw in all three Presentations as they did before.
- [ ] The pull request shows the strip, the list and `overview` on the staged desk beside the prototype at the same settings.

## Sources

- [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html). Open the file in a browser; its switches set the Tile once for every layout.
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
