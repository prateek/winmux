# Quitting WinMux puts windows back where they were

Part of {{UMBRELLA}}.

## What to build

Starting WinMux re-tiles every window. Quitting it centres every window on its monitor, at its last floating size or at the monitor's full size (`makeAllWindowsVisibleAndRestoreSize` in `Sources/AppBundle/util/appBundleUtil.swift`). Someone who tries WinMux for ten minutes and quits finds a desktop they did not arrange.

On a normal quit, each window that was open before WinMux started goes back to the frame it had then.

## Decisions

- **Keep it small.** Prateek: "I don't want to invest too much work in this." One record of frames taken before the first layout, and one restore on quit.

## Not in this issue

- Restoring WinMux's own layout at the next launch.
- Restoring Spaces, minimized state, or windows that were closed.
- Anything after a crash or a hard kill beyond what a relaunch and quit already does.

## Depends on

Nothing.

## Defaults chosen for you

- **What is recorded.** Each window's frame and display when WinMux first sees it at launch, before it is tiled. A window opened while WinMux runs has no record and stays where it is at quit, on screen.
- **Where.** In memory, and in the state directory so a quit after a config reload or a long session still has it. A record older than the running session is not used.
- **When it restores.** A normal quit and the signals that already run the shutdown path. A setting to turn it off, on by default.
- **A window the person moved to another display or resized by hand while floating** still goes back to its recorded frame. Say so in the docs.

## Done when

- [ ] Five windows at known frames, WinMux started, windows moved across two workspaces, WinMux quit: every window is at its recorded frame, on screen, checked in a guest by reading the frames before and after.
- [ ] A window opened after launch is on screen after quit.
- [ ] A window closed while WinMux ran is not reopened and causes no error.
- [ ] The pull request shows the desktop before launch, tiled, and after quit.

## Sources

- Prateek, 2026-10-06: "if we quit WinMux, especially for a short duration, the user's windows are back to what they used to be … just something that isn't so jarring for the testers."
