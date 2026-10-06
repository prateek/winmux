# Mission Control and Exposé with WinMux running

Part of {{UMBRELLA}}.

## What to build

Prateek, on `0.5.6-dogfood.12` with the shipped defaults: his Exposé shortcut gave "an Exposé-like thing" that was much slower than Exposé, was not the grid, and showed WinMux's sidebar as if it were an app's window.

WinMux binds no Mission Control or Exposé key by default and has no code that takes them over, so the likeliest reading is that this was macOS's own Mission Control, drawn badly because of what WinMux does to the desktop:

- The sidebar panel's `collectionBehavior` is `[.canJoinAllSpaces, .fullScreenAuxiliary]` (`WorkspaceSidebarPanelController.swift`), with neither `.stationary` nor `.transient`, so Mission Control treats it as a window to show.
- Windows of hidden workspaces are parked at the screen's edge, and Mission Control animates all of them.

Nobody has reproduced it. The first step is to see it in a guest.

## Decisions

- **Reproduce before fixing.** If it turns out a WinMux binding did fire (the `overview` Lens is `alt-semicolon` then `o`), say which, and this issue becomes that one.

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

- Prateek, 2026-10-06. Which keys he pressed is not recorded; ask him on the issue if the guest does not show it.
