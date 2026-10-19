# A tab group dropped on a Columns workspace with a `place` hook comes apart

Part of {{UMBRELLA}}.

## What to build

A tab group dragged onto another workspace, by a workspace row, a monitor chip, a new workspace or an on-screen workspace zone, arrives whole. When that workspace has Columns and a `place` hook, `applyPendingWindowDragIntentWithPolicy` (`WindowDragPendingIntent.swift`) then runs `ColumnPolicy.place` once for each window of the group that changed workspace. Each call unbinds that one window and binds it into a Column, so the group is taken apart window by window. A drop on a Column itself does not do this: that path binds the dragged node once, with one answer from the hook.

The Column drop-decision cache (`ColumnDropDecisionCache`) has the same blind spot. It is keyed by the dragged window, the workspace and the Columns' occupancy, not by what is being dragged. A decision the hook gave for a single window is reused when Option turns the same drag into a group drag over the same Column, and the whole group binds with the single window's answer.

**A dragged tab group moves one window when its active tab is a nested container** found both in its review. Neither is new with it: every group drag, nested or not, does this.

## Decisions

- **A dragged group arriving on a Columns workspace is placed once, as one node.** The `place` hook is asked once for the group, and its answer binds the group whole, as a Column drop does.
- **The drop-decision cache keys on the drag subject** as well as the window, so a decision made for a window is not reused for a group.

## Depends on

Nothing.

## Done when

- [ ] Tests drop a tab group by a workspace row and an on-screen workspace zone onto a Columns workspace with a `place` hook, and show the group arrives in one Column, whole, with the hook asked once.
- [ ] A test changes a drag from a window to a group over the same Column and shows the hook is asked again for the group.
- [ ] Window drops onto a Columns workspace with a `place` hook behave as before.

## Sources

- Pull request for **A dragged tab group moves one window when its active tab is a nested container**, review round one: the findings that the policy loop places each leaf and that the decision cache ignores the subject.
