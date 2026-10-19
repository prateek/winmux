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

- [ ] Tests with a tab group whose active tab is a nested split, and one whose active tab holds a nested tab group, show that every drop path moves the whole outer group, and that the preview's window count and tabs are its own.
- [ ] In a guest, such a header dragged onto a sidebar row, a workspace and a tile on screen moves the whole group each time, read back with `list-windows` and the agent tree.
- [ ] Group drags whose active tab is a plain window behave as before.

## Sources

- Pull request #251, review rounds two to four: the nested tab-group findings and why each narrower fix left a path disagreeing with the others.
