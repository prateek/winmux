# Display profiles: match a profile to the attached display

Part of {{UMBRELLA}}.

## What to build

Prateek's laptop is either docked to an ultrawide with the lid shut or used alone. Three Columns suit the ultrawide and one suits the panel. Today `columns` at the top level applies to every display, and nothing scopes it to one. His workaround is two chords that set the Column count for the current workspace, which a reload resets.

The config already has the shape, `when.<profile>`, and loads other profiles, but only the implicit `default` ever matches. This issue makes a profile match the attached display, applies the matching settings, and moves the windows.

## Decisions

- **A Display profile is a named condition that holds while a given display is attached.** Settings key on it through `when.<profile>`, as designed in #1.
- **A display is identified** as the monitor-identity research settled: the built-in flag for the laptop panel, UUID or vendor, model and serial for a physical display, a name pattern as fallback. See [monitor identity research](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/05-research-monitor-identity-and-display-change.md).
- **What can differ per profile**: Column count and widths, Lens settings, gaps, and the sidebar's mode. Not bindings or binding modes.
- **One profile at a time.** When the built-in panel and an external display are both attached, the external display's profile applies.
- **At a switch the workspaces stay and re-flow.** Widths reset to the new profile's. When the Column count drops, the extra Columns' contents are placed by `place`, as a new window would be.
- **Each profile remembers its layout.** Coming back to a display restores the arrangement that display last had, for the windows that still exist. Windows opened since are placed by `place`.
- **WinMux waits for the display to settle.** A mode change made in steps, with pauses of a second or two between them, is one switch. A CLI command forces a re-match at once, for a script that knows it has finished.

## Not in this issue

- Two displays in use at once, each with its own profile.
- Per-profile bindings.
- Moving workspaces between monitors, which `workspace-to-monitor-force-assignment` already does.

## Depends on

Nothing.

## Defaults chosen for you

- **How long is quiet.** Three seconds with no display change. The existing settle delay is 750 ms, which is shorter than the pauses in his display script.
- **The command** is `winmux display-profile --rematch`, and `winmux display-profile` prints the active one. `list-profiles`, and the active profile in `subscribe` and in the Filter context, report the real name where they report `default` today.
- **Where the remembered layout lives**: in memory and in the state directory, keyed by profile. A layout older than the config's last change to Columns for that profile is dropped.
- **A switch that lands during a drag or an open Lens** waits until it ends.
- **Floating windows** keep their size and are moved on screen if the new display is smaller.
- **Gaps** keep their `PerMonitor` spelling as well; say in the docs which wins when both are given.

## Done when

- [ ] A config with `when.<profile>` for the built-in panel and for a named display loads, and `winmux display-profile` names the one in effect.
- [ ] In a guest, where there is one display, a test hook or the display's name pattern stands in for a second display: switching profiles changes the Column count, re-flows three Columns into one, and switching back restores the three as they were.
- [ ] A window opened while the other profile was active is placed by `place` on return, and a closed one causes no error.
- [ ] A burst of display changes one second apart causes one re-flow.
- [ ] Layout and matching are covered by tests that need no display.
- [ ] `docs/` shows a two-profile config.
- [ ] A line in **Prateek's checks on an installed build and real hardware**: dock and undock on the ultrawide, with the lid shut and with it open, and run his display script.

## Sources

- The fork foundation's design, 2026-09-30, where this was deferred, and its unanswered questions: [Display profile contents and switch behaviour](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/10-grilling-display-profiles.md).
- The comment on this issue from his config work, 2026-10-06.
- Prateek, 2026-10-13: "can we unpark #47", and four answers: Columns, Lens settings, gaps and sidebar mode vary; re-flow and remember each display's layout; the external display's profile wins; WinMux waits for quiet, plus a command.
