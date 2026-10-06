# Mission Control and Exposé with WinMux running

Part of {{UMBRELLA}}.

## What to build

Prateek, on `0.5.6-dogfood.12` with the shipped defaults: the trackpad's three- or four-finger swipe for Mission Control gave "an Exposé-like thing" that was much slower than Exposé, was not the grid, and showed WinMux's sidebar as if it were an app's window.

That gesture is macOS's own. WinMux binds no Mission Control or Exposé key, handles no trackpad gesture, and has no code that takes either over. So this was Mission Control itself, drawn badly because of what WinMux does to the desktop:

- The sidebar panel's `collectionBehavior` is `[.canJoinAllSpaces, .fullScreenAuxiliary]` (`WorkspaceSidebarPanelController.swift`), with neither `.stationary` nor `.transient`, so Mission Control treats it as a window to show.
- Windows of hidden workspaces are parked at the screen's edge, and Mission Control animates all of them.

Nobody has reproduced it. The first step is to see it in a guest.

## Decisions

- **Reproduce before fixing**, in a guest, with Mission Control opened by its key (a guest has no trackpad; the gesture and `ctrl-up` open the same thing).

## Not in this issue

- Replacing Mission Control with a Lens. The `'grid` and `'miniatures` Presentations are reached by their own Triggers.

## Depends on

Nothing.

## Defaults chosen for you

- **WinMux's own panels stay out of Mission Control and App Exposé**: the sidebar, the Lens panel, the HUDs and the empty-Column outline.
- **Parked windows.** If they are what makes Mission Control slow or crowded, say what the options are and what each costs; do not change how workspaces are hidden inside this issue without saying so first in the pull request.

## Done when

- [ ] A guest capture of Mission Control and of App Exposé with WinMux running on the fourteen-window desk, before the change, with the time each takes to settle.
- [ ] After it, neither shows a WinMux panel, shown by the same captures.
- [ ] The pull request says what Mission Control does with parked windows and whether anything was done about it.

## Sources

- Prateek, 2026-10-06: "it took over my Exposé shortcuts, but it was much slower than Exposé … in the Exposé view it was using the sidebar as well, like an app." He opened it with the three- or four-finger trackpad gesture.
