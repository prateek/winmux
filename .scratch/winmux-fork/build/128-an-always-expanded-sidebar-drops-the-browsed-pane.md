# An always-expanded sidebar drops the browsed project's pane when the pointer leaves

Part of {{UMBRELLA}}.

## What to build

When the sidebar browses a project that is not the active one, its page splits into two panes and the panel widens to fit both: `browseProjectWidthChange` animates the visible width from `width` to twice it plus the pane gap (`WorkspaceSidebarViewLayout.swift`). With `workspace-sidebar.always-expanded = true`, the next hover exit undoes that. `handleHoverExit` (`WorkspaceSidebarPanel.swift`) returns early for an always-expanded sidebar with `expandSidebar(to: CGFloat(config.workspaceSidebar.width))`, the single-pane width, so the panel animates from 640 back to 320 and the browsed project's pane is cut off while the panel frame stays 640 wide. The refresh path is right: it uses the layout's `expandedWidth` through `workspaceSidebarPersistentVisibleWidth`.

To see it: set `always-expanded = true`, create a second project from the pager, browse it, and move the pointer off the sidebar. The second pane disappears. With `always-expanded = false` and the sidebar pinned, both panes stay.

**A workspace section scrolled under the sidebar's chrome takes drops there** found it while staging its split-page demo.

## Decisions

- **An always-expanded sidebar keeps the width its current page needs.** Every place that re-expands an always-expanded sidebar takes the layout's expanded width, the one the refresh already uses, not the configured single-pane width; a split page stays two panes wide until browsing ends.

## Depends on

Nothing.

## Done when

- [ ] A test with `always-expanded` on and a browsed project shows the visible width staying at the split page's width after a hover exit, and returning to `width` when browsing ends.
- [ ] In a guest, with `always-expanded = true` and a browsed project, both panes stay on screen after the pointer leaves the sidebar.
- [ ] An always-expanded sidebar on a single-project page behaves as before.

## Sources

- Pull request #260's demo pass: with `always-expanded = true` the hover debug log shows `browseProjectWidthChange … target=640`, then `expandSidebar … target=320 visible=640` from the hover exit.
