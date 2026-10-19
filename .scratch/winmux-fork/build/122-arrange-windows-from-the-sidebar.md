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
identity and index metadata. Container identities are monotonic `UInt64` values
from `TilingContainer.stableId`. `WorkspaceSidebarWorkspaceViewModel.projectedItems`
stores the display projection, with a cached window-to-Column lookup. Extend that
projection and `WorkspaceSidebarTreeRows`,
not the retained prototype JavaScript or the dormant SwiftUI drop delegate.

`WorkspaceSidebarDropTargetKind.tree` carries `WorkspaceSidebarTreeDropTarget`.
Tree targets wholly outside the scroll viewport register nothing; partly visible rows keep their whole frame. `resolveWorkspaceSidebarDropTarget`
prioritizes exact monitor/new-workspace controls, then picks the smallest containing
row and resolves its half once. `workspaceSidebarDragTarget` serves preview and commit;
`applyWorkspaceSidebarTreeDrop` resolves live container/window identities and performs
the binding. Split/tab targets that have become Columns roots cancel, including
after suspended AX reads. `siblingBindingData` is the indexed sibling
seam also used by agent-pane placement. `Columns.swift` owns the shared vertical
Column wrapper and floating-leaf binder; floating drops restore remembered sizes.
`ActiveWorkspaceSidebarDrag` owns the source identity. Split sources cancel outside
tree/workspace targets; window rows and tab headers keep on-screen behavior.
New arrangement zones belong in
this tree path and must preserve the ordinary sibling path, including hidden parents.

## Done when

- [x] On the rich desk in a guest, two windows dragged together in the sidebar become a side-by-side split, a stacked split and a tab group, one each, and `list-windows` and the screen show it.
- [x] A split row's menu turns it into a tab group and back, and **Ungroup** puts its windows back under its parent.
- [x] Clicking a split's glyph flips its direction on screen.
- [x] A plain drop on a window still makes a sibling, as the tree's draft says.
- [x] Tests cover each mapping from a sidebar gesture to a layout change at the tree's seam.

### Checks for Prateek

- [ ] On an installed build, with a real trackpad or mouse and keyboard, Option-drag window rows into a split and a tab group, and release Option mid-drag once. Pass: the zones appear while Option is held, the drop makes what the highlighted zone names, and with Option released the row shows the plain before/after line and the drop makes a sibling.

## Built and checked

- Option alone enables arrangement zones. This settles **Drop zones on a window row offer the on-screen overlay's intents** without trying a no-modifier variant: the plain before/after halves remain available without Option. One event-fed modifier value serves preview and commit and clears with the drag; a stationary Option release restores the plain preview and sibling drop.
- The row has six fixed segments, ordered tab, left, right, above, below and swap. Unoffered segments stay empty and resolve to the plain half. Window/tab rows alone offer zones. A source outside the tiling tree that is not floating is offered nothing. A window source can tab only with window tabs enabled; group sources cannot tab through a zone. Tabs offer only tab/swap for a window source, and sibling tabs in the source's own group offer none. Floating rows and structural rows keep their plain behavior.
- Splits use the pointed window's direct parent, inserting beside it at half its weight when orientation matches and otherwise wrapping it. The split is chosen after the source is removed and its workspace normalized, so a split the source leaves with one child is flattened first and normalization afterwards does not turn the new split against the zone. The windows of a split that is itself a tab, a nested container in a tab group, take only swap: splitting there can flatten the pointed window into the tab group and turn the new split, and a tab zone would nest a tab group in a tab. Direct Column children are wrapped in their existing slot; Column widths stay put. Tab and swap operate on the pointed window, including an individual tab, rather than the on-screen drag target's whole group. Floating sources record their size and become tiled; they are not offered swap, which would take the pointed window out of the tiling tree, and a refused zone is refused before the AX size read. Self/descendant and missing-target refusals retain their hover reason.
- `WorkspaceSidebarContainerActions.swift` changes containers by stable identity and workspace. The layout command retains nested containers. The sidebar's Tabs action flattens nested children to ordered leaf windows; this departs from **A container row's menu**, whose command analogy would retain them. A checked current item is a no-op. Ungroup inserts direct children in order with the container's share of its parent split among them (in their own proportions when they lie along the parent), splices in a child split that runs the parent's way so normalization does not rotate its windows (a tab group child is bound whole, and normalization keeps each split inside it running across the group's orientation, as any move of it does), joins leaves into a tab parent, and leaves an emptied split for normalization. Tabs and Ungroup keep the visible tab and every ancestor's remembered focus. The layout command and the sidebar share `TilingContainer.changeLayout`. Root and direct Column-child refusals disable Ungroup with help. Tabs is disabled when window tabs are off.
- Menu Split actions and the split glyph use the command's orientation cascade. The disclosure label keeps its drag gesture; the glyph is a separate button on a split, and plain text on a one-window tab group drawn as a split row. Normalization restores a Columns root to horizontal tiles with its slots and widths intact.
- **Refused** is narrowed by the build rulings: Column Policy has no prohibition on these groups, and a floating source may tile through a zone. No additional Column refusal was introduced. Undo remains out of scope. **A dragged tab group moves one window when its active tab is a nested container** and **A workspace section scrolled under the sidebar's chrome takes drops there** remain separate work, as does **A group dropped into a tab group shows its last window**, found in this build's review.
- Host and pinned-version guest `make check` pass: 1,720 Swift tests, 92 helper/Rust tests and 171 script tests. The guest skips the existing committed-hash check for its sync commit. Sixty-one sidebar tree tests cover all zone arrangements and eligibility, geometry, modifiers, floating/AX races, command behavior, menus, ungrouping, cascade and Column slots. Disabling zone/container application produces 35 failures in four selected tests; the restored implementation passes. An additional failing assertion established normalization's ownership of empty-container removal.
- Rich-desk screenshots, AX snapshots, `list-windows` transcripts and `agent query` raw trees check splits, tabs, swap, floating tiling, a Column-child wrapper, every menu action and the glyph. The same script against the separately built base and feature trees produces identical plain-drop input, inventory, raw trees and Column readbacks; the layout command's vertical result also matches. Stationary Option-release evidence shows the preview and commit reverting together. Proof tools are in `.scratch/winmux-fork/proofs/sidebar-arrange/`; final-commit pull request demos belong to the demo pass. No Search was used.
- Installed-build use with a real trackpad and keyboard remains Prateek's check above. No new by-hand upgrade or permission step is needed. The builder publishes no release.
- The proof driver uses `dm` for actual drag events and waits after its final release. Early plain takes that ended `cliclick` immediately after `du` sometimes left the button held and the preview open; an explicit later release committed that same drag. With the trailing wait and independent combined-session button-state checks, five base and five feature takes all make siblings. The input failures are retained as diagnostic evidence, with no app workaround.

## Sources

- Prateek, 2026-10-18, after picking the sidebar tree: "queue a follow up issue to work on - the ability to manage the layout of windows from the sidebar (eg ability to configure windows into splits/tabs/etc using the mouse in the sidebar)".
