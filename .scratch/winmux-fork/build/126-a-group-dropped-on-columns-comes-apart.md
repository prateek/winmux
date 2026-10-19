# A tab group dropped on a Columns workspace with a `place` hook comes apart

Part of {{UMBRELLA}}.

## What to build

A tab group dragged onto another workspace, by a workspace row, a monitor chip, a new workspace or an on-screen workspace zone, arrives whole. When that workspace has Columns and a `place` hook, `applyPendingWindowDragIntentWithPolicy` (`WindowDragPendingIntent.swift`) then runs `ColumnPolicy.place` once for each window of the group that changed workspace. Each call unbinds that one window and binds it into a Column, so the group is taken apart window by window. A drop on a Column itself does not do this: that path binds the dragged node once, with one answer from the hook.

The Column drop-decision cache (`ColumnDropDecisionCache`) has the same blind spot. It is keyed by the dragged window, the workspace and the Columns' occupancy, not by what is being dragged. A decision the hook gave for a single window is reused when Option turns the same drag into a group drag over the same Column, and the whole group binds with the single window's answer.

While those `place` calls await their hook, the post-drag AX suppression covers only the windows each drop intent names: the dragged node's windows and, for a swap or split, the one target window. A swap or split also moves the target's tab group or the subtree it anchors to, and those windows' moved and resized echoes are handled as fresh events until the global suppression is armed after the apply.

**A dragged tab group moves one window when its active tab is a nested container** found all three in its review. None is new with it: every group drag, nested or not, does the first two, and every swap or split the third.

## Decisions

- **A dragged group arriving on a Columns workspace is placed once, as one node.** The `place` hook is asked once for the group, and its answer binds the group whole, as a Column drop does.
- **The drop-decision cache keys on the drag subject** as well as the window, so a decision made for a window is not reused for a group.
- **Every window a drop moves is suppressed before any `place` hook runs**, the target side included.

## Depends on

Nothing.

## Done when

- [ ] Tests drop a tab group by a workspace row and an on-screen workspace zone onto a Columns workspace with a `place` hook, and show the group arrives in one Column, whole, with the hook asked once.
- [ ] A test changes a drag from a window to a group over the same Column and shows the hook is asked again for the group.
- [ ] A test swaps a group with a window in another tab group whose workspace has a `place` hook, and shows every window of both groups is suppressed while the hook runs.
- [ ] Window drops onto a Columns workspace with a `place` hook behave as before.

## Sources

- Pull request for **A dragged tab group moves one window when its active tab is a nested container**, review rounds one and two: the findings that the policy loop places each leaf, that the decision cache ignores the subject, and that a swap or split suppresses only one target window.
