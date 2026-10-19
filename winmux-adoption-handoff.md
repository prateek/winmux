# Handoff: WinMux adoption on a real laptop (2026-10-19)

Attached to the prateek/winmux issue that lists the adoption tracker. **The issue body is the item list**; this file carries the context, findings, and decisions a fresh agent needs to act on it. It does not repeat the list.

## What happened

Prateek spent a session adopting WinMux 0.5.6-dogfood.66 on a laptop that is used alone or docked lid-shut to a 32:9 ultrawide. The dotfiles side of the work is on branch `prateek/winmux-adopt` in prateek/dotfiles (local commits, not pushed or merged yet):

- `a6fafc39` BetterTouchTool bridges: trackpad swipes → WinMux Lenses, and hover move/resize
- `0c3464e0` per-display WinMux configs, laptop layout, rows toggle, Tuna `w` group
- `4fa1cc97` pin `doubleSidedWindows` off via a plist fragment
- `3ef21314` Ctrl-F opens `lens search`
- `7aad35b3` search Lens as a flat card list

Read those commits for the exact config; the relevant files are `home/dot_config/winmux/{winmux,laptop,ultrawide}.ncl`, `home/dot_local/bin/executable_winmux-{display,rows,gesture}`, `home/.chezmoiscripts/run_after_49-winmux-gestures.sh.tmpl`, `home/.chezmoitemplates/com.{hegenberg.BetterTouchTool,zimengxiong.winmux}.plist.tmpl`.

Already filed: **#263** (main-thread recursive-release crash, twice on dogfood.66, plus an opt-in crash-reporting pipeline). Relevant existing issues: **#47** display profiles (the dotfiles `winmux-display` script is the stopgap), **#85** installed-build checks, **#235** agent query file permissions, **#242**, **#257**.

## Findings a fresh agent should not rediscover

- **Fullscreen on floating windows is one-way.** `winmux fullscreen` (by `--window-id` or focused) grows a floating 800×500 window to the full panel, but `winMuxFullscreen` stays `false`, so the next call doesn't restore it. Exit 0 both times. Tiled windows toggle correctly. Repro: open any window that floats, shrink it, run `winmux fullscreen` twice, read `winmux agent query` frames.
- **Double-sided windows hides the tab strip** for exactly-two-window groups (`showsWindowTabs` is false when `usesDoubleSidedWindows`). It is a UserDefaults toggle (`doubleSidedWindows`), not config, so users who flipped it in the menu see "tabs missing" with no config clue. After turning it off the strip returned only once the workspace was re-laid out.
- **A crash leaves native Cmd-Tab disabled** (`WinMux.symbolicHotkeyMarker.v1` held ids 1 and 2). Relaunching with the Cmd-Tab bindings removed restored them and cleared the marker. WinMux doesn't relaunch itself after a crash, so the system switcher stays dead until the user notices.
- **Workspaces can't be created from the CLI.** `winmux workspace 9` and `move-node-to-workspace 9` both fail with "Workspace '9' doesn't exist"; `persistent-workspaces = ["1","2","9"]` did not create one on reload. Test harnesses that want a scratch workspace can't make one.
- **`place --dry-run` explains placement for the focused workspace,** not the window's own workspace, so it can't check a per-workspace `place` hook without moving focus.
- **No CLI to flip a workspace's root split orientation.** `layout --window-id <w> v_tiles` flips the window's parent, which is a tab group when a Column holds several windows. The dotfiles `winmux-rows` rewrites the root split via `winmux agent` layout JSON (direction flipped, floating windows carried through).
- **`winmux subscribe` sends no initial Lens state;** events look like `{"_event":"lens-opened","lens":"overview"}`. A gesture bridge that wants "close the open Lens on swipe down" has to track state itself (deferred by choice; contextual gestures are a requirement for native gesture support instead).
- **`winmux config check` is lazy** about hook bodies; a real evaluation (dry-run placement, or a reload plus `config status` `last-error`) is needed.
- **WinMux's shipped Option chords** break special characters (¡™£, ÷, …), shadow terminal Meta keys (M-digit, M-h, M-l, M-;, M-/), and alt-shift-o collides with Cursor/VS Code Organize Imports. Most shipped chords need the right hand; Prateek prefers left-hand, home-row chords on a split keyboard.
- **BTT hover move/resize keys** (undocumented, found in BTT 6.937): `controlMove`, `optMove`, `cmdMove`, `shiftMove`, `functionMove` and the `…Resize` counterparts, exact modifier match. On tiled windows BTT and WinMux fight (jitter); fine on floating windows. That is the motivation for native modifier move/resize.

## Decisions Prateek made

- Cheat sheets/leader menus are **not** a WinMux feature for now.
- Keep the URL scheme on; keep all nine workspace digits.
- Window switcher on **Ctrl-F** (Caps+F, home row), accepting that WinMux takes Ctrl-F from every app.
- Gestures stay on the BTT bridge until WinMux has native gestures; contextual behaviour (swipe down closes an open Lens) and finger-tracked, interruptible animation are requirements for the native version.
- Fullscreen spec: regular size → whole-screen view → the original size. Same Space vs new Space is undecided; at minimum it should feel like its own WinMux workspace; hiding the menu bar is wanted if feasible.
- Shipped defaults should be culled to a few everyday chords; the rest move to a leader launcher.
- Before more features land, run a **grilling session on what WinMux should become** (WM core vs launcher vs status UI vs gestures; what lives in WinMux vs the launcher vs dotfiles), including whether the dotfiles helper scripts should become native.

## Suggested next steps

1. Triage the issue's list against open prateek/winmux issues (dedupe; link existing ones such as #47, #85, #242, #257, #263), then propose umbrella issues with sub-issues in the repo's format (Part of / What to build / Decisions / Depends on / Done when / Sources). File only what Prateek approves.
2. Turn the reproduced bugs (floating fullscreen, outside-click doesn't dismiss the overview, CLI workspace creation) into standalone issues with the repros above.
3. Schedule the "what should WinMux become" grilling before building the large features (native Exposé, gestures, hints, status UI).

## Suggested skills

- `mattpocock-skills:grilling` for the "what should WinMux become" session.
- `mattpocock-skills:domain-modeling` if the grilling settles terms (Lens, Column, profile, mode) worth recording.
- `mattpocock-skills:research` for the open research items (menu bar hiding during Exposé, how other WMs do rules and saved layouts).
- `utils-agent:search` for the broader search for leader/which-key tools.
- `review:github-attachments` when an issue needs screenshots or logs attached.
- The winmux repo's own `issue-relay` skill for building filed issues.
