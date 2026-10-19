# A group dropped into a tab group shows its last window

Part of {{UMBRELLA}}.

## What to build

When the sidebar tree drops a split or a tab group into a tab group, the tab that ends up showing is the dragged group's last window, not the one that was showing. The same drop also moves the workspace's remembered focus to that window. Two drops do this: a group dropped on a tab-group header (`.tabGroup` in `applyWorkspaceSidebarTreeDrop`), and a group dropped as a sibling of a tab in a tab group. Both go through `workspaceSidebarJoinLeaves` (`WorkspaceSidebarTreeDrop.swift`), which binds the group's windows one at a time. Each `bind` calls `markAsMostRecentChild`, which raises that window in its parent and every ancestor, so the last window bound wins.

**Arrange windows from the sidebar** keeps the visible tab and the remembered focus for its own menu actions, **Tabs** and **Ungroup**, by wrapping its calls in `workspaceSidebarPreservingMru` (`WorkspaceSidebarContainerActions.swift`). Its review declined to change the drop paths, which belong to **The sidebar as a tree**.

## Decisions

- **A group joining a tab group shows the dragged group's most recently used window**, as a dropped window shows itself, and the rest of the dragged group keeps its recency order. The windows join in their order, where they join now.

## Depends on

Nothing.

## Done when

- [ ] Tests drop a split whose first window was last used onto a tab-group header and beside a tab, and show that window as the group's visible tab, with the rest of the split in their recency order.
- [ ] Window drops into a tab group behave as before.

## Sources

- Pull request #254, review round two: the finding that joining leaves through the drop paths raises each leaf in turn.
