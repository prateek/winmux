# Lens sections name the wrong workspace right after a restart and quick workspace changes

Part of {{UMBRELLA}}.

## What to build

A grid grouped by workspace can head its sections with the wrong workspaces. In the demo pass of pull request #156, on the standing desk (Zed and Ghostty on workspace 1, Safari and Notes on workspace 2, workspace 1 focused), a grid opened from the CLI headed Zed and Ghostty's section **"Workspace 2 · here"** and Safari and Notes' **"Workspace 1"**. `winmux list-windows --all` taken right after the same take put Zed and Ghostty on workspace 1 and Safari and Notes on workspace 2, and `list-workspaces --focused` printed `1`. A grid opened later in the same session, after other takes, headed both sections correctly, and so did one opened an hour later after the same focus calls without a restart.

The demo pass of pull request #154 saw the same twice: grids opened with WinMux treating workspace 2 as focused while workspace 1's windows were on screen, right after the desk's windows were focused across workspaces in quick succession through the CLI.

**What preceded it** (#156), in order, with nothing else between:

1. The debug WinMux was killed and started again.
2. `winmux workspace 2`, one second, `winmux workspace 1`, two seconds.
3. `winmux focus --window-id` on Notes, Safari, Ghostty and Zed, 0.3 seconds apart.
4. The pointer parked, one second, then `winmux lens recent --presentation grid`.

It has not been reproduced on demand. Find the cause first: run those steps in a loop in a guest, open the grid each time, and compare the section headings with `list-windows --all` and `list-workspaces --focused` read at the same moment.

**Where to look.** `LensSession` builds `sectionIdentities` and each section's `current` from the items it is given (`Sources/AppBundle/lens/LensSession.swift`, the `init`), and the items take their workspace from each window's record (`workspaceIdentity`, `workspaceName` in `SwitcherPalettePanel`'s item builder, `Sources/AppBundle/ui/hud/SwitcherPalette.swift`). The labels come from `workspaceDisplayName`. Startup drawing (`prepareAtStartup`) also builds a session from window snapshots. A record read while focus or workspace visibility is still moving, or a prepared session reused with stale items, would draw what the screen shows here.

## Decisions

- **The headings match WinMux's own model at the moment the Lens opens**: the workspace each window is on, and "here" on the focused workspace.

## Not in this issue

- How sections are ordered or labelled when the model is right.

## Depends on

Nothing.

## Done when

- [ ] The cause is named in the pull request, with the trace or log that shows it.
- [ ] A test that drives the cause through the session or the item builder fails before the fix and passes after.
- [ ] In a guest, the four steps above in a loop of twenty, each followed by a grid, head every grid's sections as `list-windows --all` and `list-workspaces --focused` say.

## Sources

- Pull request #156: its demo pass's first hero take and readbacks, and the account of the steps before it.
- Pull request #154: the two grid takes recorded under Not checked.
