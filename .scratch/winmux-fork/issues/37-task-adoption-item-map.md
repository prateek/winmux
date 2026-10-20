# #268, item by item

Where each item of the adoption tracker lands. "Draft" is a file under `build/`; "issue" is an existing GitHub issue; "dotfiles" is decided not WinMux.

## First

- Triage and restructure: this file, the umbrella draft 131, and `issues/38-task-adoption-closures.md`; beads deferred, see the end of this file.
- Grill "what should WinMux become": done 2026-10-19, `issues/36-grilling-what-winmux-becomes.md`; recorded by 153 and the umbrella.

## Switcher

- Cmd-Tab bindings parked until #263 is fixed: #263, amended; the relaunch answers the hard-kill.
- Cmd-Tab shows the current workspace; Alt-Tab falls back to native: 133 for the Lens, 139 for the command.
- Wider scopes, per app, under the mouse, project, Column: 133, as `app-windows`, `mouse-app`, `project-windows` and `column-windows`; the Column one needs the Filter context's new `column` field, which 133 adds.
- Home-row modal switcher from a leader: 133 plus the `browse` mode of 132; Tuna opens `lens search --presentation list` and `mode browse`.
- Strip buttons don't look like macOS: 156.
- Ctrl-F switcher polish: 156.

## Exposé and gestures

- Native-looking overview with a Spaces row, drops, a home for other projects' windows: 136 then 137.
- Instant opening, swipe-driven continuous transition: 49 and 137.
- Clicking outside doesn't dismiss: 138.
- Contextual gestures: 49, as keys in the open Lens's mode.
- Hide the menu bar while open: 136, a pick dimension.
- Swipe between workspaces: 49.

## Windows

- `fullscreen` on a floating window one-way: 140.
- Fullscreen round trip, same Space, menu bar: 141.
- Native modifier move and resize: 142.
- Modifier-held hints on tabs, the sidebar and move targets: tabs landed as #243; the sidebar and move targets are 157.
- Vim-style focus, last two and marks: 134 for the commands, 133 for the keys.
- Floating windows scoped to workspace, project or everything: 133, shipped Lenses.
- Workspaces from the CLI and `persistent-workspaces`: 143.

## Feedback and status

- At-a-glance mode, workspace, project: 149 for the menu bar item; 146 for everything else to consume; notch and SketchyBar are dotfiles.
- Sidebar accents and indicators: 150.
- Pause icon: 149.
- Crash logs and reporting, agent auto-triage: #106 and #263, amended.
- Pointer jumps to the top-left: 151.

## Defaults and configuration

- Cull the shipped bindings, move the rest to a leader: 133; the leader is Tuna.
- Study routing rules, per-app preferences, saved layouts; save and toggle layouts: 152.
- A command bar for layouts and fuzzy-finding: fuzzy-finding is `search` with 156's polish; layouts wait on 152; the bar itself is Tuna's.

## Not WinMux

- Cheat sheet for leader menus: dotfiles, as decided; the mode legend of 135 is WinMux's own keys only.
- Moom-style sizing mode: dotfiles.

## From the handoff's findings, not on the list

- Double-sided windows hides the tab strip: 148.
- A crash leaves native Cmd-Tab disabled: #263's relaunch.
- `place --dry-run` and the focused workspace: 144.
- No CLI for the root split orientation: 145.
- `subscribe` sends no initial state: 146.
- `config check` is lazy about hooks: 147.
- Shipped Option chords: 133.
- BetterTouchTool fights WinMux on tiled windows: 142.
- Display switching script: #47 as written.

## Open issues not on the list

Every open issue is a child of #55 or #84 and stays where it is, except #109, which joins #55's list by hand when the umbrella is filed. Five are closed by the filing, with the comments in `issues/38-task-adoption-closures.md`: #144, #145, #213, #227 and #228. The beads move is deferred; its two drafts are under `build/later/`.

## First, revisited

- Triage and restructure: this file, the umbrella draft 131, and `issues/38-task-adoption-closures.md`.
