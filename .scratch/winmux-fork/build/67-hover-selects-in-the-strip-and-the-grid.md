# Hover selects in the strip and the grid

Part of {{UMBRELLA}}.

## What to build

`docs/lenses.md` says hover selects. In `0.5.6-dogfood.13` it does in the list and in miniatures, and does nothing in the strip and the grid: the pointer over a Tile changes neither the selection nor the drawing.

Hover selects in every Presentation, the way the system's Cmd-Tab does.

## Decisions

- **The pointer is an input.** Moving it over a Tile selects that Tile. On release the last input wins, key or pointer.
- **A pointer that has not moved selects nothing.** A Lens that opens under a resting pointer keeps its keyboard selection until the pointer moves more than a point. A key step re-arms the rule, so the Tile that slides under a still pointer is not selected either.
- **A pointer that leaves the panel** leaves the selection on the last Tile it crossed.
- **A click commits**, as today.

## Not in this issue

- Window controls on a Tile. They are **The Search match highlighted, and window controls on a Tile**.
- Dragging a Tile.

## Depends on

Nothing.

## Defaults chosen for you

- **The scroll wheel steps the selection** one Tile per event, as the system's switcher does. Today it does nothing.
- **Where the defect is.** A test panel suggested every hover is reported as the raised, selected Tile's, from the order of `.position`, `.zIndex` and the hover handler in `StripView` and `GridView`. That was not confirmed in the app. Find the cause first.

## Done when

- [ ] In a held strip and in a grid, moving the pointer over another Tile selects it, and release focuses it.
- [ ] A strip opened under a resting pointer keeps the second entry selected, and Tab then steps from the second.
- [ ] Pointer on one Tile, then Tab, then release: the keyboard's Tile is focused.
- [ ] A test that fails on `0.5.6-dogfood.13` covers the strip and the grid.
- [ ] The pull request shows each of these in a guest.

## Sources

- The switching comparison, 2026-10-07 to 2026-10-09: the same pointer tests on the system's Cmd-Tab, AltTab, DockDoor and the strip.
- Prateek, 2026-10-07: "mouse hover" on his list from a day of use. 2026-10-13, choosing between the two models: hover selects, like Apple's.
