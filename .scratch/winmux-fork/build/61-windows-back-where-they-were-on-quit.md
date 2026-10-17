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

- **What is recorded.** Each non-popup window's global frame when the startup refresh first sees it, before binding or layout. A window first seen in a later refresh, including a slow app's window, has no record. At quit, a window without a record stays where it is when its cached frame is on screen and it is not parked; otherwise it is brought back on screen.
- **Where (changed).** In memory only, keyed by window id and written once. Config reload preserves the map. WinMux has no in-process restart; a Sparkle relaunch quits and restores, then launches and records again. A disk copy would serve a later process, which must not use an older session's record.
- **When it restores.** The menu's Quit, the system's quit Apple Event, and the existing signal and fatal-error cleanup paths. `restore-windows-on-quit` is a Bool, default `true`; turning it off centres every window as before, with the visible-rectangle origin fixed.
- **A window the person moved to another display or resized by hand while floating** still goes back to its recorded frame. Say so in the docs.

## Built behavior

`StartupWindowFrames.swift` records the frame already read by `MacWindow.getOrRegister`. Monitor preparation refreshes its chrome without scheduling a competing discovery refresh: that race previously let ordinary discovery register startup windows first. Startup tiling policy is unchanged.

`quitFrameAction` makes the restore/leave/centre choice from cached state and current monitors. A recorded frame is restored when its centre lies on a current display. With no usable record, an on-screen, unparked cached frame is left alone; otherwise the window is centred on the monitor nearest its last known frame, or the main monitor if that frame is unknown. The centre includes the visible rectangle's global origin.

Quit writes read no AX frame, run concurrently across apps, and keep each app's windows in order. A failed window is logged without stopping another. Cleanup runs once per process, preserving the hotkeys, frozen-world, frames order. The application delegate waits for cleanup or the same two-second deadline as signals, then allows termination. A ten-window, five-app, three-workspace guest restore took 92.4 ms, so the deadline remains two seconds.

## Done when

- [x] Five windows at known frames, WinMux started, windows moved across two workspaces, WinMux quit: every window is at its recorded frame, on screen, checked in a guest by reading the frames before and after. Checked through both the menu's Quit and a quit Apple Event, using an independent CoreGraphics reader.
- [x] A window opened after launch is on screen after quit. Checked after menu, Apple Event and signal quits; a late floating window also kept its exact new frame after config reload.
- [x] After `SIGTERM` with windows on three workspaces, every window is on screen. All nine startup windows returned to their exact frames, and the tenth, opened later, was on screen.
- [x] A window closed while WinMux ran is not reopened and causes no error. Closing Blue left it closed and restored the four surviving startup windows; injected AX failure also cannot stop later windows or another app.
- [ ] The pull request shows the desktop before launch, tiled, and after quit.

## Checks on an installed build and real hardware

- [ ] Move a recorded floating window to a second display and resize it; quit and verify its original display, position and size return.
- [ ] With restoration off, quit with a window on a second display whose origin is nonzero; verify it centres within that display's visible rectangle.
- [ ] Disconnect a recorded display; verify quit leaves an already visible window alone and brings a parked or off-screen window to the nearest remaining display (the main display when it is the only one).
- [ ] Installed-build behavior and real sleep, wake and unlock.

## Sources

- Prateek, 2026-10-06: "if we quit WinMux, especially for a short duration, the user's windows are back to what they used to be … just something that isn't so jarring for the testers."
- The switching comparison, 2026-10-07: WinMux stopped by signal between captures.
