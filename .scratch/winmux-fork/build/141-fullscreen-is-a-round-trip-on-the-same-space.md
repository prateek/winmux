# Fullscreen is a round trip on the same Space

Part of {{UMBRELLA}}.

## What to build

`fullscreen` today grows a window to the panel's visible frame and back. Prateek wants it to feel like macOS's fullscreen without the Space: a regular window, then a whole-screen view with the menu bar gone, then the original size, and while it lasts the window should feel like its own workspace.

## Decisions

- **Same Space, never a native fullscreen Space.** A native Space breaks Column placement and animates at macOS's pace. WinMux's own fullscreen class covers the whole display.
- **The menu bar is hidden while a WinMux window is fullscreen**, if an app that is not in a native fullscreen Space can hide it; the first step of the build is to find out, and if it cannot, the window covers the visible frame and the docs say why.
- **A fullscreen window stays in its workspace and covers it.** It keeps its node, Column and tab group, and the workspace keeps every other window under it; what changes is how commands see the workspace while the window is fullscreen: focus directions stay on the fullscreen window, `move` and `join-with` are refused with a message, `workspace <n>` leaves the workspace and returns to it with the window still fullscreen, the sidebar marks the window as fullscreen, and the Filter context reports the fullscreen class. Leaving fullscreen restores the window's frame and the workspace's layout exactly, since neither was changed.
- **The round trip restores the original frame**, including for a floating window, which **`fullscreen` on a floating window never records it** fixes first.

## Not in this issue

- Fullscreen on a second display while a Lens is open on the first.

## Depends on

- **`fullscreen` on a floating window never records it**.

## Defaults chosen for you

- **The transition** is WinMux's own frame animation at the Column move's duration, not the native zoom.
- **Hiding the menu bar** uses the presentation options a regular app may set, and restores them when the window leaves fullscreen, closes or WinMux quits.

## Done when

- [ ] Tests cover the round trip for a tiled and a floating window, `workspace` away and back, and focus directions while fullscreen.
- [ ] In a guest, a window goes fullscreen with the menu bar hidden or the docs' stated reason it is not, and comes back to its frame; a demo shows it.
- [ ] `docs/cli.md` describes the round trip and the menu bar.
- [ ] A line in **Prateek's checks on an installed build and real hardware**: fullscreen on the ultrawide and on the laptop panel, with the menu bar.

## Sources

- The grilling record, 2026-10-19, "Features": "Fullscreen is a round trip on the same Space".
- #268's handoff, "Fullscreen spec: regular size → whole-screen view → the original size".
