# Modifier move and resize of the window under the pointer

Part of {{UMBRELLA}}.

## What to build

Holding Ctrl and dragging anywhere on a window to move it, and Ctrl-Cmd to resize it, is what BetterTouchTool's hover move and resize do, and what Linux window managers do natively. On floating windows the BetterTouchTool bridge works. On tiled windows BetterTouchTool and WinMux both act and the window jitters, which is the native-versus-dotfiles test's second clause: it fights WinMux, so it goes native.

## Decisions

- **Ctrl-drag moves the window under the pointer; Ctrl-Cmd-drag resizes it.** The modifiers are configurable; these are the defaults. The window need not be focused.
- **A floating window moves and resizes freely**, as a title-bar drag does.
- **A tiled window's move is a node move** through the drag machinery and the Column-aware overlay that **A drag over Columns shows where the window will land** built, so a Ctrl-drag shows the same destination and drops the same way as a title-bar drag.
- **A tiled window's resize changes what the layout can change**: in a Column, the Column's width preset, stepping as the pointer crosses a preset's midpoint; in a split, the split ratio. The resize shows its result as a preview and commits on release.
- **The modifiers are read from the event stream**, `flagsChanged` and the flags on pointer events, as the relay's rule for held keys says; never from live `CGEventSource` state.
- **Escape during a modifier drag cancels it** and the window returns to where it was.

## Not in this issue

- Resizing a floating window from a corner with a different cursor per edge; one grab, proportional from the pointer's side.

## Depends on

Nothing.

## Defaults chosen for you

- **The pointer's side chooses the resize edge**: the edge nearest the pointer moves, as BetterTouchTool does.
- **A modifier drag on the sidebar, a Lens or the tab strip** is ignored.

## Done when

- [ ] Tests cover a floating move and resize, a tiled move with the overlay's destination, a width-preset step and a split-ratio change, and Escape.
- [ ] In a guest, demos of each: a Ctrl-drag of a floating window, a Ctrl-drag of a tiled window into another Column, a Ctrl-Cmd-drag that steps a Column's width.
- [ ] `docs/` describes the two drags and the config for their modifiers.
- [ ] A line in **Prateek's checks on an installed build and real hardware**: with the BetterTouchTool bridge off, both drags on a trackpad, floating and tiled, with no jitter.

## Sources

- The grilling record, 2026-10-19, "Features".
- #268's handoff, "BTT hover move/resize keys" and the jitter on tiled windows.
