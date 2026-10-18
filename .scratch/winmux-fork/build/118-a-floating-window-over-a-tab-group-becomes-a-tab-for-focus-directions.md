# A floating window over a tab group becomes a tab for focus directions

Part of {{UMBRELLA}}.

## What to build

For the length of each `focus` command, `makeFloatingWindowsSeenAsTiling` (`Sources/AppBundle/command/impl/FocusCommand.swift`) binds the workspace's floating windows into the tiling tree, then puts them back. It binds each one beside the window under its centre, and `CGPoint.findIn(tree:virtual:)` answers a tab group with its active tab. So a floating window over a tab group is bound inside the group, next to the active tab, and directions along the group's orientation (`focus left` and `focus right` in a horizontal group, `focus up` and `focus down` in a vertical one), `dfs-next`, `dfs-prev` and `--dfs-index` treat it as a tab: `focus right` from the active tab of a horizontal group reaches the floating window instead of the next tab.

**The ninth tab digit goes to the last tab** took tab targets (`--tab-index`, `tab-next`, `tab-prev`) out of this step, through `FocusCmdTarget.addressesTabs`. Directions and dfs still go through it. Keep that exemption after this fix: tab targets never need floating windows in the tree.

Binding the floating window beside the outermost tab group instead was tried during that issue and reverted. A review found these cases where that attempt went wrong, which a fix has to handle:

- **A root that is a tab group.** The outermost group would then be the workspace's root, whose parent is no tiling container, so the attempt bound the floating window nowhere and directions and dfs could not reach it.
- **The fallback.** When `findIn` returns nil, the window is bound at index 0 of the root, which is tab 1 when the root is a tab group; the attempt left this path alone.
- **Which side.** The attempt compared the floating window's centre with the leaf window under it while indexing relative to the group; with two floating windows over different leaves of a split inside the active tab, they landed on the wrong sides and out of order. Compare with the group's own frame.
- **A perpendicular parent.** Beside a group inside a vertical split, a floating window to its right went above or below the group, out of `focus right`'s reach.
- **Coming back.** From a floating window right of a horizontal group, `focus left` snapped to the group's last child, which switches the active tab instead of returning to it.

## Decisions

- **A floating window is never a tab.** No `focus` target treats it as one of a group's tabs.

## Defaults chosen for you

- **Where it goes for directions**: beside the outermost tab group, on the side its centre falls on in that group's parent, with the group's frame as the reference, and `focus` back into the group lands on the active tab. When the root itself is the tab group, there is no outside: the floating window stays out of the tree for the command, as for tab targets.

## Depends on

**The ninth tab digit goes to the last tab**, which adds the tab-target exemption this builds beside.

## Done when

- [ ] `focus right` from the active tab of a horizontal group with a floating window over it reaches the next tab.
- [ ] Tests cover a root tab group, nested groups, the `findIn` fallback, a perpendicular parent and two floating windows.
- [ ] `focus left` from a floating window right of a group returns to the group's active tab.

## Sources

- Found while building **The ninth tab digit goes to the last tab**, 2026-10-18, in `/code-review` rounds 2 and 3 on its pull request.
