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

- **The scroll wheel steps the selection** over the strip or grid panel. A line wheel steps once per event. A trackpad steps once after four accumulated vertical points, only when vertical movement exceeds horizontal movement; remaining events and momentum do not step again. Precise events with no gesture phases retain one step per burst, reset after 200 ms of quiet. Strip steps wrap as Tab does; grid steps follow entry order and stop at the ends. The list scrolls its rows.
- **Where the defect is.** The base guest confirmed oversized post-position hover regions: callbacks named the selected strip Tile at points over other Tiles, and strip/grid traces retained the selection. Its grid click correctly focused the clicked Tile, refuting that part of the suspicion. Nonactivating panels also receive pointer movement through both local and global AppKit routes; both must reach the panel's one hover callback.

## Done when

- [x] In a held strip and in a grid, moving the pointer over another Tile selects it, and release focuses it.
- [x] A strip opened under a resting pointer keeps the second entry selected, and Tab then steps from the second.
- [x] Pointer on one Tile, then Tab, then release: the keyboard's Tile is focused.
- [x] A test that fails on `0.5.6-dogfood.13` covers the strip and the grid.
- [ ] The pull request shows each of these in a guest.

## Built

Strip and grid hover and clicks hit-test the cached layout frames through the session. The selected scaled frame wins overlaps; gaps, headers, the footer and Search select nothing. Text Tiles retain their unscaled hit frame. The pointer anchor uses a strict Euclidean distance greater than one point, re-arms on non-pointer state/layout changes and navigation at an edge, and records movement through non-Tile areas without selecting. Miniatures shares that motion guard and re-arms on page turns; the list keeps its row hover path.

Scoped local/global mouse delivery feeds the existing hosting view and its single panel hover callback while a strip or grid is shown; dismissal and conversion remove the monitors. A held grid now commits on release, including release while opening. A key-ended Hold never commits. Grid clicks subtract Trigger modifiers as Return does and retain additional modifiers such as Shift for Summon.

Session regressions cover every Tile centre, selected-frame overlaps (including extreme aspects), gaps/chrome, the one-point threshold, redraw under a still pointer, same-window Search reselection, key/page/wheel re-arming, click keys, both release orders and wheel gesture/boundary behavior. Event-delivery tests cover coordinates, visibility, pass-through and monitor cleanup. The guest probe in `.scratch/winmux-fork/probes/hover-selects/check-pointer.zsh` failed eight target assertions on the actual base; the fixed build passed forty moves across twenty sessions. The hover handlers and old motion guard relevant to this defect are equivalent between the base and the commit named by `0.5.6-dogfood.13`.

The standing-desk debug run checked held strip/grid hover and focus, resting-pointer/Tab, both input orders, exit, clicks, grouping, Search and Return, list/miniature preservation, line wheels and phased precise/momentum events. The held grid used a temporary Control-Option-Tab config Trigger; shipped bindings do not open one held. Final PR demos are the driver's step and the PR checkbox stays unticked until they are attached.

### Checks for Prateek

- [ ] Installed-build behavior.
- [ ] A second display and real sleep, wake or unlock.
- [ ] Physical trackpad/mouse-wheel use; synthetic line and precise phased/momentum events were checked in the guest.

## Sources

- The switching comparison, 2026-10-07 to 2026-10-09: the same pointer tests on the system's Cmd-Tab, AltTab, DockDoor and the strip.
- Prateek, 2026-10-07: "mouse hover" on his list from a day of use. 2026-10-13, choosing between the two models: hover selects, like Apple's.
