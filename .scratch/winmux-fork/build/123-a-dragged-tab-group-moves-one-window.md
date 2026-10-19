# A dragged tab group moves one window when its active tab is a nested container

Part of {{UMBRELLA}}.

## What to build

Dragging a tab group's header can move only part of the group. This happens when the group's active tab is not a window but a container: a nested split, or a split holding another tab group, which `columnBinding` builds when a Column slot held a split. The header starts the drag with its representative window (`tabActiveWindow`, which can sit inside the nested container) and subject `.group`. Every drop path then resolves the dragged node from that window: `dragSubjectNode(for:subject:)`, which is `window.moveNode` for `.group`, and `beginActiveWorkspaceSidebarDrag` in the sidebar. `moveNode` (`MoveCommand.swift`) is the tab group only when the window's direct parent is the tab group. So the drop moves the window alone, or the inner tab group, whether it lands on the screen, a sidebar row, a workspace, a monitor chip or a new workspace.

Review rounds two to four of pull request #251 tried narrower fixes. Walking to the nearest tab-group ancestor picks the inner group when tab groups nest. Passing the header's container to the sidebar drag alone made its preview disagree with what the on-screen path and the monitor-chip fallback moved. **The sidebar as a tree** therefore keeps the base resolution on every path, so they all agree, and leaves the fix to this issue.

## Decisions

- **A group drag moves the group whose header was dragged.** The drag carries that container's `TilingContainer.stableId`, not a representative window, from the moment it starts. The sidebar's tree drops, workspace and new-workspace drops, monitor chips, the on-screen drop, the preview's window count and tab list, and the pending drop intent all resolve that one container.

## Not in this issue

- Window drags and tab-strip drags, which move a window.

## Depends on

Nothing.

## Done when

- [x] Tests with a tab group whose active tab is a nested split, and one whose active tab holds a nested tab group, show that every drop path moves the whole outer group, and that the preview's window count and tabs are its own.
- [x] In a guest, such a header dragged onto a sidebar row, a workspace and a tile on screen moves the whole group each time, read back with `list-windows` and the agent tree.
- [x] Group drags whose active tab is a plain window behave as before.

## Built and checked

The group subject carries the header container's `UInt64` stable id from every start. One live-container lookup searches workspace tiling trees; the representative window still supplies the session window id, focus, frame gate and anchor fallback. Group resolution never falls back to that window. A flattened or unbound container gives no destination, preview or pending intent, and an already pending drop refuses it.

Tab-strip chrome and copied strip models retain the container id. Flat sidebar headers, their drag payloads and actions carry the same id; tree rows start the same subject. The active sidebar source is derived once from that subject. Option promotion still requires the window's direct parent to be a multi-child tab group. Window and detached-tab subjects, target resolution, drop zones, Column placement and Policy hooks retain their behavior. This does not change which tab a group drop shows.

Thirteen `NestedGroupDragTest` tests use both shipped normalization settings and assert that both fixture shapes survive normalization. The fixtures cover strip, flat-sidebar and tree-sidebar starts; on-screen lookup and pending apply; Column policy apply; sidebar window and split rows; workspace, new-workspace and monitor-chip drops; preview counts and leaf tabs; anchor/ghost/model identity; containment refusal; stale ids before and after an intent is set; and session/intent identity. The first base run failed the tile, tree-row, workspace and preview regressions. Restoring the old source resolution after implementation failed nine tests with 101 assertions. Existing tests changed their call sites only; their assertions remain unchanged.

Host and pinned-toolchain guest `make check` pass: 1,733 Swift tests, 92 helper/Rust tests and 171 script tests. The guest script suite skips its existing committed-hash check for the sync commit. CI's swift.org toolchain remains the pull request's gate.

The drag-start seam tests unsubscribe the mouse driver's native display callback after each synchronous start. Their explicit pointer samples own the test drag; a real tick with no mouse button held otherwise treats it as a missed mouse-up and can leave a refresh running after the test. That leak was caught by a full guest run entering real AX code under test mocks, then removed without changing assertions.

The guest pointer script builds fixture A with `join-with` and `layout tab-group`, and fixture B through Columns and `move-node-to-column`. Screenshots show each nested shape, the whole group crossing a tile, the sidebar row reorder and the workspace transfer, including previews listing all three or four leaves. Every drop has a fixed-delay `list-windows --all` and agent readback. The agent raw tree compacts a tab group's nested children to representative ids; its inventory, sidebar hierarchy and exact staging commands supply the additional shape evidence. The same plain-active-tab script against the base and feature builds produces identical input coordinates and final tree/window summaries. Proof tools are in `.scratch/winmux-fork/proofs/group-drag/`. No Search or permission grant was used. Builder evidence uses stills after the system video recorder stalled without a prompt; final pull request demos are separate.

No Default was changed. The builder publishes no release, and no by-hand upgrade or permission step is introduced.

### Checks left with Prateek

- [ ] Pointer and keyboard use on the installed build.
- [ ] A second physical display.
- [ ] Real sleep, wake and unlock.

## Sources

- Pull request #251, review rounds two to four: the nested tab-group findings and why each narrower fix left a path disagreeing with the others.
