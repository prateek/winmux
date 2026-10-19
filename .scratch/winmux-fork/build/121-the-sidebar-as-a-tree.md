# The sidebar as a tree

Part of {{UMBRELLA}}.

## What to build

Build Prateek's 2026-10-18 pick from **Prototype: the sidebar as a tree**: a numbers-only rail, expanding on hover to a shallow layout tree with width-proportional Column marks. Two independent workspace toggles reveal split and Column levels. Drop windows or tab groups on any row; a window target means “insert as its sibling at the pointed index”.

Extend the existing native sidebar snapshot, row and drag owners. Keep stable workspace, Column, container and window identities, Column widths, tab order and container layout/orientation. Resolve drops through the binding and Column-placement seams. Start by rendering the flat view from that snapshot, then add optional levels and mutations. The [prototype](../prototypes/83-sidebar-tree/index.html#pick) is evidence; its JavaScript is not native implementation to import.

## Decisions

- The tree is the layout: workspace, Column, tab group or split, window. Hiding a structural level changes presentation and never changes the real parent or drop result.
- Rows collapse, drag to a new parent, and can be searched. Preserve disclosure choices through search and layout updates.
- A tab group and a split look different. Tab groups remain a row with their tabs on a bracketed child rail. Revealed splits show their orientation glyph and layout (tiles; this fork has no accordion, which config migrates to tab groups).
- The sidebar runs collapsed, expanding on hover. The rail shows workspace numbers only, with today's focused-workspace highlight; no app icons or Column marks.
- The prototype is a clickable comparison page, retained with its variants below **The pick**. It answers questions and ships no native behavior. Copy no extension code or assets into WinMux.
- Default to a flat, shallow tree. Ordinary tiled windows sit directly under the workspace; tab groups retain their tabs; floating windows sit flat under the workspace too, each marked with a small floating glyph. Windows have no Column tag. Each workspace with Columns carries proportional marks, its focused Column filled; hovering a window highlights its Column's mark.
- Tiny **Splits** and **Columns** buttons at the right of each workspace have tooltips and accessible labels. **Splits** reveals both the split (BSP) levels and the floating group, which is a grouping of the same kind. The Columns button is absent on workspaces without native Columns. They affect only that workspace and are independent: both on gives workspace → Column → split/tab group → window.
- Two config defaults, both false, set starting states. A workspace click overrides its default until that default changes. Proposed names: `sidebar.tree.splits` and `sidebar.tree.columns`.
- A window-row drop inserts before the target in its upper half and after it in its lower half, in its actual parent. A tab target joins its group at that index. A direct Column child gains a sibling in that Column's container; a lone window becomes a vertical split, matching `bindToColumn`'s `.split` branch.
- Workspace rows and rail numbers keep invariant placement for a node from another workspace: nearest empty Column, then focused occupied Column. A drop on the workspace the node is already on is accepted and changes nothing. Today `isActionableSidebarWorkspaceDropTarget` (`WindowDragSidebarDestinations.swift`) refuses it, and that guard is shared with on-screen drags over the sidebar and stays: lifting it would append the node to the root (`workspaceAppendBindingData`, `INDEX_BIND_LAST`). The tree's own drop path checks for it before that guard and accepts it, with no move, while on-screen drags over the sidebar keep the guard: today a sidebar-row drag runs the guard in both preview and commit (`workspaceSidebarDragTarget`, `commitActiveWorkspaceSidebarDragIfPossible`), so a short-circuit placed after it never fires. Column rows/marks bind the dragged node with `bindToColumn`, as the drag overlay's `.column` intent does (`move-node-to-column` moves one window within its own workspace and cannot carry a group or a node from another workspace); split rows insert or append. A tab group row takes a window as a tab, and a dragged tab group or split as its windows, in order, at the end; a tab takes them at its index. Which tab ends up in front follows WinMux's own most-recent rule and is not set by this feature. A Column mark is a different path (`columnBinding`), which wraps a nested occupant in a new tab group. Occupied Columns merge incoming group leaves into tabs; empty Columns preserve the group. Existing native hooks remain authoritative.
- A floating window dropped on a tiled window, tab, tab group, split or Column is tiled first (`layout tiling`) and placed by the same rule. On a workspace row or rail number it stays floating, as `applySidebarWorkspaceMove` keeps it today. A floating group/window target keeps it floating. Floating a dragged group floats its leaf windows, as `bindToColumn` does.
- Refuse self/descendant cycles and dragging structural workspace/Column rows as layout nodes, with the reason visible before mutation. A window row is a sibling destination, never a request to give a window children. No other existing row is refused for a window or tab group.

## Defaults chosen for you

- Expanded width: 320 points when unset. The captured pick measures 307 points in flat and both-level views, including the prototype's retained 44-point rail. Native Nickel defaults use 50 collapsed and 280 expanded; the config initializer has 240 expanded. Preserve explicit configured widths and native compact geometry; tail-clip arbitrary longer titles and expose them on hover.
- Rows: native 12.5-point window text, 13-point group headers, 14-point icons, 24-point window rows, 32-point workspace rows and 18-point indentation. Taller trees scroll.
- Search: case-insensitive app/title substring, counted once per window. Keep ancestors visible and dimmed; reveal matching paths without changing disclosure state.
- Disclosure: tab groups and revealed layout levels start open. Keep choices by stable node identity for the sidebar session; no new persistent disclosure store.
- Pin: an explicit expanded reading state using the existing expansion lock. Retain native hover timing and activation behavior. The page retains its rail beside the tree for comparison; native compact contents can be replaced during expansion as today.
- Toggle state: defaults are config-owned and survive reload. Overrides live in sidebar session state by workspace identity. Changing a default clears that toggle's overrides only. The page models defaults in local storage and overrides in memory.
- Drop affordances: stable upper/lower insertion lines, container outlines and visible refusal reasons. With levels off, preview the actual hidden-parent insertion; native preview and layout readback must agree with the prototype's sketch. A native sketch is not part of this feature. Resolve current identities/indices again before native binding.

## Depends on

Nothing. The prototype and Prateek's choice are available. Two seams are built within this feature. Binding a node to a parent at an index: `moveNodeToSiblingIndex` (`MoveCommand.swift`) and `workspaceInsertBindingData` (`WindowDragWorkspaceBinding.swift`) are file-private, and the second decides before or after by the parent's orientation, not by a row's halves. And joining a group's windows to a tab group: the existing join and `.tabStack` take a window. The tree shows the layout after WinMux's own normalization, which flattens a non-Columns root whose only child is a container; the prototype does not model that.

## Done when

- [x] On the fourteen-window rich desk in a 1920 × 1080 guest, the collapsed rail shows numbers only and focused numbers use today's treatment. Capture collapsed and hover-expanded states on all workspaces; pin/unpin and existing activation work.
- [x] The default tree has no split/Column levels or window Column tags. Tabs remain grouped; Updater and Calculator sit flat under workspaces 1 and 4 with a floating glyph, and turning Splits on for a workspace shows its floating group. Workspace 2's marks are 28/44/28, workspace 3's are 2/3–1/3, and hovering windows highlights their marks. Workspaces 1 and 4 have none.
- [x] Each toggle reveals its level on workspace 2 only. Both on shows Column → tab group → tab and any split produced by a sibling drop, with the actual orientation glyph. Columns is absent on workspaces 1 and 4.
- [x] Each config default sets starting state and survives config/app reload. A local click affects one workspace; changing a default clears only that toggle's overrides. Check each default separately and both together.
- [x] Drop on the upper/lower halves of a window with levels off and on. `list-windows`/the agent layout show the source before/after the target in its actual split; the preview agrees. Repeat on a tab and a direct Column child, the latter forming a vertical split without adding a Column.
- [x] Floating Calculator dropped on a tiled row becomes tiled at the pointed destination, confirmed by `list-windows` and the layout. Dropped on workspace 1's row it stays floating there. A floating target keeps it floating; a dragged group floats as leaf windows. Notes dropped on workspace 2's own row changes nothing, and the Safari tab group dropped on the TextEdit tab group joins it as three tabs after Grievances and Soft language. Workspace/Column rows, marks, tab groups, splits and rail numbers accept drops, including same-workspace destinations.
- [x] Self/descendant drops and dragging workspace/Column headings are refused with visible reasons and no layout mutation. No other existing target is refused. Stale targets are re-resolved or safely cancelled before binding.
- [x] Collapse Safari/TextEdit groups, search and clear. `Safari` finds 3 windows in workspace 2 / Column 2 / Safari tabs; `Grievances` finds 1 in workspace 3 / Column 1 / TextEdit tabs; `qzxnomatch` finds 0. Counts and ancestor paths agree and clearing restores disclosures.
- [x] Behavior tests and a native guest run cover invariant workspace placement, explicit Columns, occupied-Column group merging and native hooks. Focus, marks, rail and rows update together after moves, tab changes, closes and workspace switches.
- [x] Measure native clipping in flat and both-level views at 240, 280 and 320 points, light/dark, and a shorter usable height. Explain any departure from the prototype's 307-point threshold.
- [x] Host and pinned-version guest `make check` pass; latest GitHub `Build and test` passes before landing. Retain visible evidence and the final native layout readback.
- [ ] Prateek checks the installed build with his sidebar config and pointer timing, a second display and real sleep/wake/unlock. Record any by-hand upgrade or permission step in [Prateek's checks on an installed build and real hardware](https://github.com/prateek/winmux/issues/85).

## Built and checked

Built from the native tree, not the prototype JavaScript. The existing snapshot
model now carries the complete layout, real-parent/index metadata, empty Column
slots, exact width fractions and remembered focused Column. Its projection hides
levels without changing binding destinations. The compact header already drew
numbers only and needed no change to its contents or focused-number treatment.
Root children with no valid Column slot remain listed after the Column rows until
normalization assigns them. Each snapshot stores its display projection and window
to Column lookup; tab headers reuse the window models already built for children.

Decided: the actual keys are `workspace-sidebar.tree.splits` and
`workspace-sidebar.tree.columns`, under the existing sidebar table. This replaces
the proposed `sidebar.tree.*` spelling above. Both defaults are false. Both native
expanded-width defaults are 320; explicit widths, including the upstream
conversion fixture's 280, remain unchanged. The conversion test adjusts that width
expectation alone, and the shipped JSON was regenerated by the helper.

Decided: Column labels round fractions to whole percentages; the marks use the
original fractions. Structural split/Column heading clicks toggle disclosure, as
does their chevron. Workspace clicks activate the workspace. No named **Default
chosen for you** changed.

Session overrides live with the sidebar model, not in `sidebar.json`. Each default
clears only its own override map on reload. Disclosure uses workspace names,
workspace/slot pairs and monotonic `UInt64` container identities; obsolete identities
are pruned. Normalization or replacement of a container resets that container to open.
Search opens matching paths only in the projection and restores every disclosure
when cleared. The pin button uses the existing expansion lock.
Search retains the base's workspace/project matches, empty-workspace results,
bundle ID/path and tab-group title fields, and all whitespace-separated terms.

Mouse drops use registered frames and the existing sidebar preview/commit path.
A tree frame wholly outside the scroll viewport registers no target; a partly visible row keeps its whole frame, so its halves stay where they are drawn. Exact monitor and
new-workspace controls take priority; otherwise the smallest containing frame wins.
Row halves resolve once, and row hit slop is zero. Commit resolves live identities
and parents again, including after a floating source's AX size read. The sibling
seam accounts for same-parent removal. A direct
Column child gets a vertical wrapper without changing Column count or widths.
Joining a group inserts its leaves in order and leaves native MRU/focus alone.
Same-workspace workspace-row drops short-circuit before the unchanged on-screen
guard. Structural/cyclic refusals show a dashed outline and reason before mutation.
The active sidebar drag owns its source identity. Split rows are sidebar-only
sources: they accept tree/workspace targets and cancel elsewhere. Window rows and
tab headers retain on-screen behavior, with feedback running outside the sidebar.
A split/tab target that has become a Columns root cancels before mutation, also
after a suspended AX read. Floating targets restore remembered floating sizes.
`Columns.swift` owns the shared vertical wrapper and floating-leaf binding;
agent-pane placement also uses the sidebar's sibling-index correction. The dormant
SwiftUI drop delegate, on-screen subjects and `move-node-to-column` remain unchanged.

Tests first passed on the base for
`testFlatProjectionPreservesNativeItemsAndFloatingWindows` and
`testExistingWorkspaceRowMovePreservesFloatingAndAppendsTiledNode`; their original
assertions pass afterward. The flat-list test now calls the projection directly.
Behavior tests cover projection, sibling indices in both
directions/halves, cross-parent/workspace placement, nested group insertion,
Columns, floating conversion, stale targets, refusals, search/disclosure, selective
reload, nested frames, adjacent rows and preservation of native feedback/monitor
preview behavior. Host and pinned-version guest `make check` pass: 1,690 Swift,
92 helper/Rust and 171 Python tests. The guest's existing committed-hash check
skips for a VM sync commit. The merge gate requires GitHub **Build and test** to pass on the head that lands.

A tab group whose active tab is a nested split or a nested tab group still drags
as its representative window's `moveNode` on every path, as before this feature,
so the preview and every drop agree. **A dragged tab group moves one window when
its active tab is a nested container** carries the container itself through the
drag.

Native rich-desk captures cover all four rail/hover states, activation and pinning,
both levels independently/together, exact marks and hover, 26 synthetic pointer
drop/refusal cases, all default/reload/restart combinations, and search/clear.
Native readbacks confirm ordered siblings/tabs, unchanged Column widths, floating
membership and no mutation on refusals. Safari joins as three tabs after the two
TextEdit tabs. Closing Subscription events removes it and leaves two Safari tabs.
Search finds Safari 3, Grievances 1 and qzxnomatch 0, on the specified paths;
clearing restores the collapsed groups and Column choice. The same script on the
base and feature builds produces identical inventory, native frames/layout,
focused window and Column state. The same sidebar workspace move and native Place
hook agree on both, including the hook's Column-3 split destination. Separate native
Column-command, tab-strip reorder and on-screen split takes also match the base's
trees and window frames. Inactive tabs are focused once during restaging so their
last off-screen AX sizes do not carry unrelated history into that comparison.
The final run repeats both sibling halves with levels hidden/revealed, both direct
Column-child halves, Safari joining TextEdit and a split moving as one source.
Split releases over an on-screen tile and New Workspace leave layout/inventory
unchanged. A window-row drag shows the native on-screen overlay. Scrolled pinning
and a New Workspace drop work. Independent native frame reads confirm a terminal
going from 500 × 320 floating to 607 × 1025 tiled and back to 500 × 320.

At 240 points, flat clips workspace 2/3 headings and the long Safari group title;
both levels also clip the editor and floating-dialog titles. At 280 and 320 these
rich-desk labels fit in both views. Font/frame measurements estimate 272 points
for this native fixture; arbitrary longer titles still clip. The prototype's 307
includes its retained 44-point rail and different chrome; native expansion replaces
that rail and uses native controls/text. System light/dark takes agree; the sidebar
retains its existing dark appearance. Decided: a 360-point menu-bar reserve gives
the shorter usable-height take without resizing the guest. Scrolling reaches the
lower workspaces while the header stays fixed. The chosen 320-point default stays.

Reproduction tools and artifact validators live in
`../proofs/sidebar-tree/`. Driver-owned captures/readbacks and their index remain
outside the public repository. No permission was granted and no builder release
was published. Installed-build config/pointer timing, a second display and real
sleep/wake/unlock remain Prateek's, unticked above. This build requires no new
by-hand upgrade or permission step.

## Sources

Prateek, 2026-10-18, verbatim:

> - in the rail - i prefer it to be just the numbers
> - i like the proportional marks to be displayed with a shallow/flat tree by default. and to have tiny icons on the right of workspace to toggle the tree showing bsp groupings and column groupings if the user clicks/configures it as such
> - i also want to be able to drag and drop windows in the sidebar on any targets. if someone drops it on a window, not a container - it should just assume we want to make it a sibling for now

Later the same day: "i think the bsp toggle should control bsp+floating container grouping".

- **Prototype: the sidebar as a tree**, its Decisions and [README](../prototypes/83-sidebar-tree/README.md).
- [Captured desk](../prototypes/83-sidebar-tree/desk.json) and [raw agent tree](../prototypes/83-sidebar-tree/raw/agent.json).
- At [`1fbbdc72`](https://github.com/prateek/winmux/tree/1fbbdc72): sidebar snapshot/row/drop owners, `WindowDragWorkspaceBinding`, `ColumnPolicy.dropDecision`, `ColumnPlacement`, `Columns.bindToColumn` and the file-private `moveNodeToSiblingIndex` in `MoveCommand.swift`. The README links the operations and names the seams this feature needs.
