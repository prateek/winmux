# Quitting WinMux puts windows back where they were

Part of {{UMBRELLA}}.

## What to build

Starting WinMux re-tiles every window. Quitting it used to centre every window on its monitor, at its last floating size or at the monitor's full size. Someone who tried WinMux for ten minutes and quit found a desktop they did not arrange. `restoreWindowsOnQuit` in `Sources/AppBundle/util/appBundleUtil.swift` now restores startup frames by default.

On a normal quit, each window that was open before WinMux started goes back to the frame it had then.

A quit by signal is worse than a normal one today. After `SIGTERM` to `0.5.6-dogfood.13` in a guest, only the visible workspace's windows were on screen; the windows of hidden workspaces stayed parked at the screen's corner.

## Decisions

- **Keep it small.** Prateek: "I don't want to invest too much work in this." One record of frames taken before the first layout, and one restore on quit.

## Not in this issue

- Restoring WinMux's own layout at the next launch.
- Restoring Spaces, minimized state, or windows that were closed.
- Anything after a crash or a hard kill beyond what a relaunch and quit already does.

## Depends on

Nothing.

## Defaults chosen for you

- **What is recorded.** Each non-popup window's global frame when WinMux first sees it before startup finishes, before binding or layout, whichever refresh sees it. A window first seen after startup, including a slow app's window or one `after-startup-command` opens, has no record. At quit, a window without a record stays where it is unless it is parked on a hidden workspace or its cached frame is off every display; then it is centred on screen.
- **Where (changed).** In memory only, keyed by window id and written once. Config reload preserves the map. WinMux has no in-process restart; a Sparkle relaunch quits and restores, then launches and records again. A disk copy would serve a later process, which must not use an older session's record.
- **When it restores.** The menu's Quit and the system's quit Apple Event, through one application delegate, and the three signals. The die path still runs the cleanup off the main thread, and no longer waits for it without limit. `restore-windows-on-quit` is a Bool, default `true`; turning it off centres every window as before, with the visible-rectangle origin fixed.
- **A window the person moved to another display or resized by hand while floating** still goes back to its recorded frame. Say so in the docs.

## Built behavior

`StartupWindowFrames.swift` records the frame `MacWindow.getOrRegister` already reads, for every window registered before `isWinMuxRuntimeReady`. A refresh the startup session did not start can register a window first, so recording follows the runtime's readiness, not the session's event.

`quitFrameAction` makes the restore, leave or centre choice from cached state and current monitors. A recorded frame is restored when its centre lies on a current display. Without a usable record, an unparked window stays where it is unless its cached frame is off every display; a move or resize drops that cache, so a tiled window often has none, and is still left alone. A parked window is centred on the display it was parked on; any other is centred on the display nearest its last frame, or the main one. A centred frame starts inside the visible rect, so its title bar stays reachable.

Before the frames are written, refresh sessions stop: the active one is cancelled and awaited, and none starts again, so nothing tiles or parks a window after it is restored. The writes read no AX frame, run concurrently across apps and in order within one, and try the position even when the size is refused. A failed or vanished window is logged and stops no other. The menu's Quit goes through the application delegate, so every quit shares one cleanup and the two-second deadline; with Accessibility denied, startup's own quit skips the cleanup and keeps the frozen world. A ten-window, five-app, three-workspace restore took 92.4 ms in a guest.

## Done when

- [x] Five windows at known frames, WinMux started, windows moved across two workspaces, WinMux quit: every window is at its recorded frame, on screen, checked in a guest by reading the frames before and after. Checked through both the menu's Quit and a quit Apple Event, using an independent CoreGraphics reader.
- [x] A window opened after launch is on screen after quit. Checked after menu, Apple Event and signal quits; a late floating window also kept its exact new frame after config reload.
- [x] After `SIGTERM` with windows on three workspaces, every window is on screen. All nine startup windows returned to their exact frames, and the tenth, opened later, was on screen.
- [x] A window closed while WinMux ran is not reopened and causes no error. Closing Blue left it closed and restored the four surviving startup windows; injected AX failure also cannot stop later windows or another app.
- [ ] The pull request shows the desktop before launch, tiled, and after quit.

## Sources

- Prateek, 2026-10-06: "if we quit WinMux, especially for a short duration, the user's windows are back to what they used to be … just something that isn't so jarring for the testers."
- The switching comparison, 2026-10-07: WinMux stopped by signal between captures.
