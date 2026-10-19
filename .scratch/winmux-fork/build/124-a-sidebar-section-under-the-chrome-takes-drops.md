# A workspace section scrolled under the sidebar's chrome takes drops there

Part of {{UMBRELLA}}.

## What to build

A workspace section that is partly scrolled under the sidebar's fixed chrome still takes drops on its hidden part. The chrome is the monitor selector and search field at the top, and the project pager and clock at the bottom. The section registers its whole frame as a `.workspace(name)` drop target, and `workspaceSidebarDropTarget(at:)` keeps any target whose centre is inside the panel. A window dragged in the sidebar and released over the pager, the clock or a gap between monitor chips, above or below a section that is scrolled half out of view, moves to that section's workspace, though nothing of it shows there.

**The sidebar as a tree** clips its own row targets to the scroll viewport, so a row's hidden part takes no drop, and leaves section targets as they were. Review round five of pull request #251 found the section case.

## Decisions

- **Only what is on screen takes a drop.** Every drop target inside the sidebar's scroll view is clipped to the visible viewport, the way tree rows are, and a point over the fixed chrome resolves to the chrome's own target or to none.

## Depends on

Nothing.

## Done when

- [ ] A test with a section frame running under the top and bottom chrome resolves a point over the chrome to no section, and a point on the section's visible part to the section.
- [ ] In a guest, with a section scrolled half under the pager, a window released over the pager stays where it was, read back with `list-windows`.
- [ ] Drops on fully visible sections, monitor chips and the new-workspace section behave as before.

## Sources

- Pull request #251, review round five.
