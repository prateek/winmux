# Arrange windows from the sidebar

Part of {{UMBRELLA}}.

## What to build

**The sidebar as a tree** shows the layout and moves windows between parents: a drop on a window makes it a sibling, and a drop on a container joins it. It cannot yet say what kind of group to make. Turning two windows into a split or a tab group, changing a split's direction or unwrapping a group still takes a key binding or a drag on the windows themselves.

Make the sidebar tree a place to arrange the layout with the mouse: make splits and tab groups, change them and take them apart, from the rows.

## Decisions

- **The layout is arranged from the sidebar with the mouse**: windows go into splits and tab groups, and back out, without a key binding.
- **It builds on the tree's own rows and drags**, as the tree's draft defines them. A plain drop on a window still makes a sibling.

## Defaults chosen for you

- **Drop zones on a window row.** While a window is dragged over another window's row, the row shows three zones, as the on-screen drag overlay does: its leading third and trailing third make a split of the two (side by side or stacked, by the split glyph shown on hover), and its middle makes a tab group of the two. Holding no modifier gives the tree's plain sibling drop; the zones show while Option is held. Prateek may prefer zones without a modifier; the build tries both and says which it chose.
- **A container row's menu.** A right-click on a split or tab group row offers **Tabs**, **Split side by side**, **Split stacked** and **Ungroup**, each mapping to the existing layout commands (`layout tab-group`, `layout h_tiles` and `layout v_tiles` on that container, and for **Ungroup** the nearest seam the code has, since `flatten-workspace-tree` works on a whole workspace).
- **The split glyph is a button.** Clicking a split's orientation glyph flips it, as `layout horizontal vertical` does for the focused container.
- **Undo** is not built: the menu and the drop are each one ordinary layout change.
- **Refused**, with the reason on hover: a split or tab group inside a Column whose Policy forbids it, if the Column code has such a rule, and any arrangement of floating windows other than tiling them first.

## Depends on

- **The sidebar as a tree**.

## Done when

- [ ] On the rich desk in a guest, two windows dragged together in the sidebar become a side-by-side split, a stacked split and a tab group, one each, and `list-windows` and the screen show it.
- [ ] A split row's menu turns it into a tab group and back, and **Ungroup** puts its windows back under its parent.
- [ ] Clicking a split's glyph flips its direction on screen.
- [ ] A plain drop on a window still makes a sibling, as the tree's draft says.
- [ ] Tests cover each mapping from a sidebar gesture to a layout change at the tree's seam.

## Sources

- Prateek, 2026-10-18, after picking the sidebar tree: "queue a follow up issue to work on - the ability to manage the layout of windows from the sidebar (eg ability to configure windows into splits/tabs/etc using the mouse in the sidebar)".
