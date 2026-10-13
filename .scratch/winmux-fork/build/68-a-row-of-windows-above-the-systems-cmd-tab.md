# Prototype: a row of windows above the system's Cmd-Tab

Part of {{UMBRELLA}}.

## What to build

With the system's Cmd-Tab left alone, a person lands on an app and not on a window. DockDoor has an option that fills the gap without taking the key: while the system's switcher is up, it draws a row of the highlighted app's windows above it, and a second key moves into that row.

Build a throwaway prototype of the same idea in WinMux and report whether it is worth an issue.

## Decisions

- **The system's switcher is not replaced, disabled or drawn over.** WinMux adds a panel above it and removes it when the switcher closes.
- **The row shows the highlighted app's windows**, with the workspace each is on. Choosing one focuses it, on a hidden workspace too.
- **With nothing chosen in the row, release does what the system does.**
- **Off by default**, behind one setting.
- **A prototype answers questions; it does not ship.** No code or asset of DockDoor, which is GPL-3, is copied. Its behaviour was observed and its approach read.

## Questions to answer

- Can WinMux read which app the switcher has highlighted? DockDoor reads it from the Dock's accessibility tree, through an element with an undocumented subrole. Does that work on macOS 26 and 27, and how late is the first reading after Cmd-Tab goes down?
- Which key moves into the row? DockDoor uses Cmd-A. Does taking one key while Command is held need the event tap, and does it disturb the system's switcher?
- What happens under secure input, and when the Dock restarts?
- Two faults seen in DockDoor to avoid: a click on a preview closed the system's switcher, switched nothing and left the row on screen; and moving the pointer up to the row crosses the system's icons, which follow the pointer and change the highlighted app.

## Depends on

- **The system's Cmd-Tab stays the system's unless the config asks for it**.

## Done when

- [ ] A prototype under `.scratch/winmux-fork/prototypes/` that runs in a guest, with a capture of the row following the highlighted app.
- [ ] Each question above answered in its README, with what was run.
- [ ] A recommendation: build it, with a draft issue; or drop it, with the reason.

## Sources

- The switching comparison, 2026-10-09: DockDoor 1.40.7 in a guest, and its source read at the same tag.
- Prateek, 2026-10-13, choosing who owns Cmd-Tab: Apple's switcher, WinMux's open view, "plus a window row above Cmd-Tab".
