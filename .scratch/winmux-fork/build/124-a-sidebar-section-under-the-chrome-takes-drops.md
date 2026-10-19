# A workspace section scrolled under the sidebar's chrome takes drops there

Part of {{UMBRELLA}}.

## What to build

A workspace section that is partly scrolled under the sidebar's fixed chrome still takes drops on its hidden part. The chrome is the monitor selector and search field at the top, and the project pager and clock at the bottom. The section registers its whole frame as a `.workspace(name)` drop target, and `workspaceSidebarDropTarget(at:)` keeps any target whose centre is inside the panel. A window dragged in the sidebar and released over the pager, the clock or a gap between monitor chips, above or below a section that is scrolled half out of view, moves to that section's workspace, though nothing of it shows there.

**The sidebar as a tree** clips its own row targets to the scroll viewport, so a row's hidden part takes no drop, and leaves section targets as they were. Review round five of pull request #251 found the section case.

## Decisions

- **Only what is on screen takes a drop.** Every drop target inside the sidebar's scroll view is clipped to the visible viewport, the way tree rows are, and a point over the fixed chrome resolves to the chrome's own target or to none.

## Depends on

Nothing.

## Done when

- [x] A test with a section frame running under the top and bottom chrome resolves a point over the chrome to no section, and a point on the section's visible part to the section.
- [x] In a guest, with a section scrolled half under the pager, a window released over the pager stays where it was, read back with `list-windows`.
- [x] Drops on fully visible sections, monitor chips and the new-workspace section behave as before.

## Built and checked

Every frame emitted inside a sidebar page's scroll view is intersected with the viewport by `workspaceSidebarVisibleTargets`. Fully hidden targets are removed. A partly hidden target keeps its whole frame beside the visible one: a tree row's halves and zones come from it, and a section or New Workspace ranks by it among slop hits, so how far the list is scrolled does not change which target wins. The viewport travels through the screen conversion in `workspaceSidebarScreenDropTargets`. `WorkspaceSidebarDropTarget.interactionRect(hitSlop:)` owns slop for both the resolver and the title-bar intent: it stops at the viewport's top and bottom, where the chrome starts, and reaches across as before, so a drop in the gap between a split page's two panes still lands in the nearer section. Monitor chips sit outside the scroll view and keep their slop. The collapsed-panel centre filter's code is unchanged; it now tests the visible part's centre, so the visible top of a section taller than the panel takes drops, as the Decision says. The exact-control preference, actionable-target predicate and drop delegates are unchanged.

Six new tests cover clipping through resolution with zero slop and the title-bar path's 12-point slop, monitor-chip slop, a fully visible section's slop inside the viewport, visible controls, the actual title-bar destination's interaction rectangle, the split-pane gap, scroll-independent ranking and the screen conversion. Only the permitted existing viewport test was edited, extending it to section and New Workspace frames. The new tests first failed on the base implementation after a completed build; independently removing only the slop bound fails six assertions. Host and Swift 6.4 guest `make check` pass: 1,738 Swift tests, 92 helper/Rust tests and 171 script tests. The guest skips the existing committed-hash script check for its synthetic sync commit.

In the 1280 × 720 guest, fifteen owned stage windows span five workspaces. Scrolling places workspace 5 at y=514–631 with the viewport ending at y=573. Both sidebar-row and title-bar drops at y=580 keep the window on workspace 2 and restore its visible tile. Held screenshots show no workspace-5 highlight. The archived base build moves the window to workspace 5 and lights its section at the same pointer position. Both drag kinds still move to workspace 5's visible part and fully visible workspace 3; a title-bar drop on New Workspace creates workspace 6. The same script runs those five cases against both builds, with matching inputs and destinations. Screenshots were inspected alongside `list-windows` and agent-tree readbacks. Monitor chips and top chrome are tested without staging another display or opening Search. No Search or permission grant was used. Proof tools: `.scratch/winmux-fork/proofs/chrome-drops/`.

No issue Decision or Default changed. No by-hand upgrade step is needed. The builder publishes no release.

## Sources

- Pull request #251, review round five.
