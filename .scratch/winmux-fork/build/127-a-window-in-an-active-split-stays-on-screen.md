# A window in a tab group's active split stays on screen when its workspace hides

Part of {{UMBRELLA}}.

## What to build

When a tab group's active tab is a split, every window of that split is on screen: the tab-group branch of `layoutRecursive` (`layoutRecursive.swift`) lays out the whole active child and parks only the other tabs. The refresh's unhide rule disagrees. `shouldKeepWindowHiddenForVisibleWorkspaceLayout` (`refresh.swift`) keeps a window "hidden" unless it is its nearest tab group's `tabActiveWindow`, a single representative. So a window of the active split that was ever parked, as an inactive tab or on a hidden workspace, is never unhidden: layout places it on screen while `isHiddenInCorner` stays true. When its workspace is later hidden, `hideInCorner` (`MacWindow.swift`) sees the stale flag and returns without moving it, and the window stays on screen over the next workspace.

To see it: make a tab group whose active tab is a split of two windows, one of which was an inactive tab before (or build the shape with Columns and `move-node-to-column`), then run `workspace <another workspace>`. One window of the split stays on screen. A drag that moves the group to another workspace leaves the same window behind.

**A dragged tab group moves one window when its active tab is a nested container** found it in its demos: its group drags now move such a group whole, and the window left behind is this rule, not the drag.

## Decisions

- **A window stays hidden only when, for some enclosing window-tab group, the child of that group on the path to the window is not the group's active child.** Every window inside the active child's subtree is unhidden, so a split's windows and an inner tab group's active window come back, and an inner group's inactive tabs stay parked.

## Depends on

Nothing.

## Done when

- [ ] A refresh test with a tab group whose active tab is a split, one of whose windows was parked before, switches to another workspace and shows every window of the group hidden; switching back unhides the split's windows and keeps an inner tab group's inactive tab hidden.
- [ ] Tab groups whose active tab is a window behave as before.

## Sources

- Pull request #256's demo pass: after a sidebar drop on another workspace, one window of the active split stayed on the emptied workspace; a plain `workspace 1` switch with no drag did the same.
