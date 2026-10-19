# A tab group dragged to the screen from the sidebar moves one window

Part of {{UMBRELLA}}.

## What to build

Dragging a tab group's header out of the sidebar and dropping it on the screen moves only one window when the group's active tab is not a window. That happens when the active tab is a nested split, or a split holding another tab group, which `columnBinding` builds when a Column slot held a split. The header starts the drag with its representative window (`tabActiveWindow`, which can sit inside the nested container) and subject `.group`. The on-screen drag resolves the group as `dragSubjectNode(for:subject:)`, which is `window.moveNode`. `moveNode` (`MoveCommand.swift`) is the tab group only when the window's direct parent is the tab group, so here it is the window alone. The on-screen preview says one window, and the drop pulls that window out of the group.

**The sidebar as a tree** fixed the same mismatch for drops on sidebar rows: the header passes its own container to the active sidebar drag. On-screen drags keep `dragSubjectNode`, which this issue changes. Review round three of pull request #251 found it.

## Decisions

- **A group drag moves the group whose header was dragged.** On-screen drops, the preview's window count and the pending drop intent act on the same container as a drop on a sidebar row.

## Not in this issue

- Window drags and tab-strip drags, which move a window.

## Depends on

Nothing.

## Done when

- [ ] A test with a tab group whose active tab is a nested split, and one whose active tab holds a nested tab group, shows the on-screen drag's subject node and its preview count are the dragged group.
- [ ] In a guest, a header dragged from the sidebar onto a tile on screen moves the whole group, read back with `list-windows` and the agent tree.
- [ ] Group drags whose active tab is a plain window behave as before.

## Sources

- Pull request #251, review round three: the nested tab-group finding, and the fix there for sidebar-row drops.
