# The sidebar as a tree

Part of {{UMBRELLA}}.

## What to build

Build Prateek's 2026-10-18 pick from **Prototype: the sidebar as a tree**: a numbers-only rail, expanding on hover to a shallow layout tree with width-proportional Column marks. Two independent workspace toggles reveal split and Column levels. Drop windows or tab groups on any row; a window target means “insert as its sibling at the pointed index”.

Extend the existing native sidebar snapshot, row and drag owners. Keep stable workspace, Column, container and window identities, Column widths, tab order and container layout/orientation. Resolve drops through the binding and Column-placement seams. Start by rendering the flat view from that snapshot, then add optional levels and mutations. The [prototype](../prototypes/83-sidebar-tree/index.html#pick) is evidence; its JavaScript is not native implementation to import.

## Decisions

- The tree is the layout: workspace, Column, tab group or split, window. Hiding a structural level changes presentation and never changes the real parent or drop result.
- Rows collapse, drag to a new parent, and can be searched. Preserve disclosure choices through search and layout updates.
- A tab group and a split look different. Tab groups remain a row with their tabs on a bracketed child rail. Revealed splits show orientation glyphs and actual layout labels, including accordion.
- The sidebar runs collapsed, expanding on hover. The rail shows workspace numbers only, with today's focused-workspace highlight; no app icons or Column marks.
- The prototype is a clickable comparison page, retained with its variants below **The pick**. It answers questions and ships no native behavior. Copy no extension code or assets into WinMux.
- Default to a flat, shallow tree. Ordinary tiled windows sit directly under the workspace; tab groups retain their tabs; floating windows retain their floating group. Windows have no Column tag. Each workspace with Columns carries proportional marks, its focused Column filled; hovering a window highlights its Column's mark.
- Tiny **Splits** and **Columns** buttons at the right of each workspace have tooltips and accessible labels. The Columns button is absent on workspaces without native Columns. They affect only that workspace and are independent: both on gives workspace → Column → split/tab group → window.
- Two config defaults, both false, set starting states. A workspace click overrides its default until that default changes. Proposed names: `sidebar.tree.splits` and `sidebar.tree.columns`.
- A window-row drop inserts before the target in its upper half and after it in its lower half, in its actual parent. A tab target joins its group at that index. A direct Column child gains a sibling in that Column's container; a lone window becomes a vertical split, matching `bindToColumn`'s `.split` branch.
- Workspace rows and rail numbers keep invariant placement: nearest empty Column, then focused occupied Column. Column rows/marks use `move-node-to-column`; tab group rows join; split rows insert or append. Occupied Columns merge incoming group leaves into tabs; empty Columns preserve the group. Existing native hooks remain authoritative.
- A floating window on a tiled target is tiled first (`layout tiling`) and placed by the same rule. A floating group/window target keeps it floating. Floating a dragged group floats its leaf windows, as `bindToColumn` does.
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

Nothing. The prototype and Prateek's choice are available. Exact-index window targeting needs a sidebar adapter over existing sibling-binding seams, within this feature.

## Done when

- [ ] On the fourteen-window rich desk in a 1920 × 1080 guest, the collapsed rail shows numbers only and focused numbers use today's treatment. Capture collapsed and hover-expanded states on all workspaces; pin/unpin and existing activation work.
- [ ] The default tree has no split/Column levels or window Column tags. Tabs remain grouped; Updater and Calculator remain in floating groups. Workspace 2's marks are 28/44/28, workspace 3's are 2/3–1/3, and hovering windows highlights their marks. Workspaces 1 and 4 have none.
- [ ] Each toggle reveals its level on workspace 2 only. Both on shows Column → tab group → tab and any split produced by a sibling drop, with the actual orientation glyph. Columns is absent on workspaces 1 and 4.
- [ ] Each config default sets starting state and survives config/app reload. A local click affects one workspace; changing a default clears only that toggle's overrides. Check each default separately and both together.
- [ ] Drop on the upper/lower halves of a window with levels off and on. `list-windows`/the agent layout show the source before/after the target in its actual split; the preview agrees. Repeat on a tab and a direct Column child, the latter forming a vertical split without adding a Column.
- [ ] Floating Calculator dropped on a tiled row becomes tiled at the pointed destination, confirmed by `list-windows` and the layout. A floating target keeps it floating; a dragged group floats as leaf windows. Workspace/Column rows, marks, tab groups, splits and rail numbers accept drops, including same-workspace destinations.
- [ ] Self/descendant drops and dragging workspace/Column headings are refused with visible reasons and no layout mutation. No other existing target is refused. Stale targets are re-resolved or safely cancelled before binding.
- [ ] Collapse Safari/TextEdit groups, search and clear. `Safari` finds 3 windows in workspace 2 / Column 2 / Safari tabs; `Grievances` finds 1 in workspace 3 / Column 1 / TextEdit tabs; `qzxnomatch` finds 0. Counts and ancestor paths agree and clearing restores disclosures.
- [ ] Behavior tests and a native guest run cover invariant workspace placement, explicit Columns, occupied-Column group merging and native hooks. Focus, marks, rail and rows update together after moves, tab changes, closes and workspace switches.
- [ ] Measure native clipping in flat and both-level views at 240, 280 and 320 points, light/dark, and a shorter usable height. Explain any departure from the prototype's 307-point threshold.
- [ ] Host and pinned-version guest `make check` pass; latest GitHub `Build and test` passes before landing. Retain visible evidence and the final native layout readback.
- [ ] Prateek checks the installed build with his sidebar config and pointer timing, a second display and real sleep/wake/unlock. Record any by-hand upgrade or permission step in [Prateek's checks on an installed build and real hardware](https://github.com/prateek/winmux/issues/85).

## Sources

Prateek, 2026-10-18, verbatim:

> - in the rail - i prefer it to be just the numbers
> - i like the proportional marks to be displayed with a shallow/flat tree by default. and to have tiny icons on the right of workspace to toggle the tree showing bsp groupings and column groupings if the user clicks/configures it as such
> - i also want to be able to drag and drop windows in the sidebar on any targets. if someone drops it on a window, not a container - it should just assume we want to make it a sibling for now

- **Prototype: the sidebar as a tree**, its Decisions and [README](../prototypes/83-sidebar-tree/README.md).
- [Captured desk](../prototypes/83-sidebar-tree/desk.json) and [raw agent tree](../prototypes/83-sidebar-tree/raw/agent.json).
- At [`1fbbdc72`](https://github.com/prateek/winmux/tree/1fbbdc72): sidebar snapshot/row/drop owners, `WindowDragWorkspaceBinding`, `ColumnPolicy.dropDecision`, `ColumnPlacement`, `Columns.bindToColumn` and `MoveCommand.moveNodeToSiblingIndex`. The README links the operations and names the adapter this feature needs.
