# Overview draws a workspace not yet shown at the wrong positions

Part of {{UMBRELLA}}.

## What to build

`overview` places each window from its last applied layout frame. A workspace that has not been laid out since WinMux started has no such frame, so its windows fall back to a remembered frame (`miniatureFrame`, then the last frame the system reported), and those can be anything: where the window sat before WinMux parked it, or the corner it was parked in.

On the fourteen-window desk, opening `overview` right after a restart, before visiting workspaces 2 to 4, drew the Notes window floating in the middle of workspace 2, a Finder window spilling out of workspace 3's cell below the arrangement, and the floating Calculator outside workspace 4's cell. A tab group's fan is drawn from its active tab's frame, so it is misplaced the same way: the Safari fan of workspace 2 sat at the screen's right edge, outside every cell, and the TextEdit fan of workspace 3 below the arrangement. After visiting each workspace once, the same desk draws correctly. Restarting WinMux and opening `overview` is the common way to meet this, and `overview` is the view that stays open. The `demo` skill's staging and the comparison scripts visit every workspace first to get past this.

## Decisions

- **A window on a workspace not yet laid out is drawn where WinMux would put it**, not where the system last saw it. The layout computes frames without applying them, and `overview` uses those.
- **Opening `overview` moves no window and changes no tree weight.**

## Not in this issue

Pictures of windows that have never been on screen since WinMux started. They stay icons until captured.

## Depends on

Nothing.

## Done when

- [ ] On the fourteen-window desk, `overview` opened right after a restart draws every workspace as it does after each has been visited, tab-group fans included, with the same frames to within a point.
- [ ] Opening it moves no window: the frames the system reports are the same before and after.
- [ ] The layout code that computes these frames is the one that lays out a workspace, not a copy.

## Sources

- Pull request [#147](https://github.com/prateek/winmux/pull/147): its builder's and its demo pass's cold openings of the staged desk, and the review finding that a copy of the tab-group geometry would drift from the real layout.
