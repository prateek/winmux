# With `always-expanded`, the sidebar's search takes every key typed anywhere

Part of {{UMBRELLA}}.

## What to build

With `workspace-sidebar.always-expanded = true`, the sidebar's type-to-search is active from the moment WinMux starts, wherever the pointer is. Its session-wide key tap takes every plain and Shift-only key, Return, Escape and Delete, from every app. In a guest on the standing desk, with Ghostty focused and the pointer never over the sidebar, typing `clear`, Return and `echo` into Ghostty put `clearecho` in the sidebar's search; Ghostty received nothing. Base `3877046b` and the build of **Ctrl-Up does nothing while the pointer is over the expanded sidebar** behave the same.

The cause, read from the code: the search begins whenever the sidebar reaches its expanded width or posts `workspaceSidebarWillExpandNotification` (`WorkspaceSidebarView.swift`, `beginSidebarSearchIfNeeded`), and under `always-expanded` the panel is always at that width, and `handleHoverExit` calls `expandSidebar` again, which posts the notification. A hover search does not end on a click elsewhere (`cancelsOnPointerExit` is false), so nothing ends it.

`always-expanded` is off in the shipped defaults.

With two displays, each panel can hold a search and a key tap at once, while the tap's callback reads and re-enables only `WorkspaceSidebarPanel.activeInlineTextEditingPanel`. Whoever builds this decides whether a tap should carry its own panel.

## Decisions

- **Typing goes to the focused app unless the person is searching the sidebar.** Under `always-expanded`, type-to-search starts only while the pointer is over the sidebar, and ends when it leaves, as it does when the sidebar collapses.

## Not in this issue

- Type-to-search under the pointer in the other modes, which **Ctrl-Up does nothing while the pointer is over the expanded sidebar** settled.

## Depends on

Nothing.

## Done when

- [ ] Under `always-expanded`, keys typed with the pointer away from the sidebar reach the focused app, checked in a guest on base and head with one script.
- [ ] Under `always-expanded`, type-to-search still works with the pointer over the sidebar, and ends when the pointer leaves.
- [ ] The collapsing modes behave as before.

## Sources

- The driver's check while landing **Ctrl-Up does nothing while the pointer is over the expanded sidebar**, 2026-10-17; the probe is `.scratch/winmux-fork/proofs/sidebar-shortcuts/always-away.zsh`.
