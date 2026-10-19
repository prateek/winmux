# Arrange windows from the sidebar

Part of {{UMBRELLA}}.

## What to build

**The sidebar as a tree** shows the layout and moves windows between parents: a drop on a window makes it a sibling, and a drop on a container joins it. It cannot yet say what kind of group to make. Turning two windows into a split or a tab group, changing a split's direction or unwrapping a group still takes a key binding or a drag on the windows themselves.

Make the sidebar tree a place to arrange the layout with the mouse: make splits and tab groups, change them and take them apart, from the rows.

## Decisions

- **The layout is arranged from the sidebar with the mouse**: windows go into splits and tab groups, and back out, without a key binding.
- **It builds on the tree's own rows and drags**, as the tree's draft defines them. A plain drop on a window still makes a sibling.

## Defaults chosen for you

- **Drop zones on a window row offer the on-screen overlay's intents.** Over a window on screen, `WindowIntentZoneBuilder` (`mouse/intent/WindowIntentZone.swift`) gives a top band that makes a tab group (`.tab`), left and right thirds that split side by side, top and bottom of the centre column that split stacked, and a centre that swaps the two windows. Each side zone also says where the dragged window lands (`WindowDropZone.stackSplitPosition`: left, right, above, below). A 24-point row cannot hold that grid, so the row lays the same six intents out along its width: tab group, left, right, above, below, swap. Each zone names its intent on hover, with the overlay's glyph. The row builds its zones from the tree's own rules rather than reusing the overlay's `destinationFromWindowDropIntent` as is: that builder offers the tab zone for a group subject and only the apply step refuses it, `shouldSuppressSameTabGroupTabDestination` hides the tab zone whenever source and target share a tab group whatever the drag's origin, and for a drag that starts as a window drag, as a tree-row drag does, `dragIntentTargetNode` falls through to the target tab's `moveNode`, its whole tab group, so swap and split over any tab, in any group, would act on that group rather than the pointed tab. The row offers the tab zone only for a window and with `window-tabs` on; a group joins a tab group by a plain drop, as its windows. Over a sibling tab of its own group, a tab is offered no zones, leaving the plain sibling drop, which reorders. Holding no modifier gives the tree's plain sibling drop; the zones show while Option is held. Prateek may prefer zones without a modifier; the build tries both and says which it chose.
- **A container row's menu.** A right-click on a split or tab group row offers **Tabs**, **Split side by side**, **Split stacked** and **Ungroup**, each changing that container's layout as `layout tab-group`, `layout h_tiles` and `layout v_tiles` do. Those commands take a window (`--window-id`) and act on its parent, so a container whose children are all containers cannot be reached through them: the build adds a seam that changes a container by its identity, used by the menu and the glyph. **Ungroup** needs one too, since `flatten-workspace-tree` works on a whole workspace.
- **The split glyph is a button.** Clicking a split's orientation glyph flips it, as `layout horizontal vertical` does for the focused container.
- **Undo** is not built: the menu and the drop are each one ordinary layout change.
- **Refused**, with the reason on hover: a split or tab group inside a Column whose Policy forbids it, if the Column code has such a rule, and any arrangement of floating windows other than tiling them first.

## Depends on

- **The sidebar as a tree**.

## Native seams from the tree build

`WorkspaceSidebarItemViewModel.children` holds the actual layout tree with real-parent
identity and index metadata. `WorkspaceSidebarWorkspaceViewModel.projectedItems`
hides optional levels for display. Extend that projection and `WorkspaceSidebarTreeRows`,
not the retained prototype JavaScript or the dormant SwiftUI drop delegate.

`WorkspaceSidebarDropTargetKind.tree` carries `WorkspaceSidebarTreeDropTarget`.
`resolveWorkspaceSidebarDropTarget` picks the smallest containing row and resolves
its half once. `workspaceSidebarDragTarget` serves preview and commit;
`applyWorkspaceSidebarTreeDrop` resolves live container/window identities and performs
the binding. `workspaceSidebarSiblingBindingData` is the indexed sibling seam.
Split and tab-group drag sources retain container identity in the sidebar's own drag
state; on-screen window subjects remain unchanged. New arrangement zones belong in
this tree path and must preserve the ordinary sibling path, including hidden parents.

## Done when

- [ ] On the rich desk in a guest, two windows dragged together in the sidebar become a side-by-side split, a stacked split and a tab group, one each, and `list-windows` and the screen show it.
- [ ] A split row's menu turns it into a tab group and back, and **Ungroup** puts its windows back under its parent.
- [ ] Clicking a split's glyph flips its direction on screen.
- [ ] A plain drop on a window still makes a sibling, as the tree's draft says.
- [ ] Tests cover each mapping from a sidebar gesture to a layout change at the tree's seam.

## Sources

- Prateek, 2026-10-18, after picking the sidebar tree: "queue a follow up issue to work on - the ability to manage the layout of windows from the sidebar (eg ability to configure windows into splits/tabs/etc using the mouse in the sidebar)".
