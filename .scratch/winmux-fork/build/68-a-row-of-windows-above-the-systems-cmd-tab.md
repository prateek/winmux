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

- [x] A prototype under `.scratch/winmux-fork/prototypes/` that runs in a guest, with a capture of the row following the highlighted app.
- [x] Each question above answered in its README, with what was run and the macOS 27 limit stated.
- [x] A recommendation: build it, with a draft issue; or drop it, with the reason.
- [ ] If reconsidered, check on macOS 27; this pass ran macOS 26.6.2 only.
- [ ] If reconsidered, check an installed signed build and a real keyboard, a second display, and real sleep/wake/unlock with Prateek.

## Prototype result

The standalone Swift experiment is in `.scratch/winmux-fork/prototypes/32-window-row-above-cmd-tab/`, with its README, two small captured stills and reproducible guest drivers. It adds no WinMux behavior or setting and no tests. Host and Swift-6.4 guest `make check` passed. A separately built base and the current build ran the same native-switcher/inventory script and retained the same fourteen-window inventory and focus, with no symbolic hotkeys held.

On macOS 26.6.2 the Dock exposes `AXProcessSwitcherList`, `AXSelectedChildren`, its frame and selection notifications. Across twelve synthetic-key openings, first-read min/median/max were 158.005/166.958/177.754 ms; the first row ordered at 181.200/196.964/213.810 ms. These are driver upper bounds and AppKit ordering is not calibrated on-glass presentation. Later Tab/Shift-Tab reads take roughly 1–5 ms. The row follows three apps, shows Ghostty windows on workspaces 1 and 3, accepts Cmd-A and navigation without changing the native highlight, and focuses the hidden-workspace choice after system release. Nothing chosen makes no focus call. Release, Escape, Tile and outside clicks remove the row. Both Dock restart cases recover. Secure Input preserves AX reads and modifier events but removes Tab and Cmd-A from the tap. Pointer crossing changes the native highlight.

**Drop it for now.** Even first read misses the accepted 150 ms budget in this guest; the full row orders at a median 197 ms. Post-release focus visibly passes through another window, and Secure Input removes entry into the displayed row. Reconsider with installed/physical-keyboard evidence of an opening around 150 ms, an acceptable intermediate-window transition and an explicit Secure Input policy, then check macOS 27 and multiple displays. No follow-up feature draft or GitHub issue is proposed. The off-by-default feature Decision remains unchanged.

## Sources

- The switching comparison, 2026-10-09: DockDoor 1.40.7 in a guest, and its source read at the same tag.
- Prateek, 2026-10-13, choosing who owns Cmd-Tab: Apple's switcher, WinMux's open view, "plus a window row above Cmd-Tab".
