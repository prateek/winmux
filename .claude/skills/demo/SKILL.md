---
name: demo
description: Make the demos for a WinMux pull request, one captioned GIF per claim, from a storyboard written before any filming. Use when a pull request changes something a person can see or operate and needs its demos, or when Prateek asks for a demo of a feature.
---

# Demo

A **demo** is one looping GIF and its caption, proving one **claim**: a sentence a viewer can confirm by watching one loop. A **take** is the raw recording a demo is cut from. The **storyboard** is the ordered list of a pull request's demos, written and checked before anything is filmed.

The viewer is a reviewer who has not read the issue. Every choice below serves one test: they read the caption, watch one loop, and can say whether the claim is true.

`$SKILL` is this directory. `$OUT` is the directory the caller names for takes, demos and the storyboard.

## 1. Write the storyboard

Read the pull request's diff and its issue's **Done when** list. Cut the work into claims: a Done-when item may split into several claims or share one. Write `$OUT/storyboard.md` in the format of [storyboard.md](storyboard.md).

- A claim where something moves gets a demo.
- A **Watch** that names a count gets it from a run of the query on the same desk, not from a guess: in the relay, the match counts the first pass wrote in `captures/index.md`.
- Choose windows by their minimum width. Safari will not go narrower than 574 points, so at 1280 by 720 it cannot be the window that lands in a quarter-width Column; Ghostty can.
- Notes will not go below 709 by 300 points at 1280 by 720, so a storyboard cannot place it smaller.
- A failed config save opens WinMux's Config Error dialog over everything, Settings included. A take whose **Watch** is something behind it, such as Settings' error banner, closes the dialog as a step in the take, or shows that state as a still.
- Notes strips custom-scheme links such as `winmux://`, so a claim about clicking one cannot be staged in a note. Use `open` typed in Ghostty, or a page Safari serves.
- The debug build's menu bar item can draw a blank icon while its hit area still opens the menu. Find the item and its Quit from a screenshot, not from the icon.
- A grid packs the standing desk's four windows into one row at 1280 by 720, so `j` and `k` have nowhere to go. A take that moves vertically needs a Lens with `sections = 'workspace` and `grid.sections-arrangement = 'rows`, which puts each workspace on a row of its own.
- A list, grid or strip opens on the entry after the focused one, and an arrow or `h` `j` `k` `l` at an edge keeps the selection. Write a **Watch** from that starting entry, not from the focused window.
- A strip cannot be typed into: a letter or `/` turns it into a list. A take of a strip showing a Search binds a chord in the desk's config to `lens <name> --presentation strip --search '<text>'` and holds it. Write that config as a literal file and reload; escaping its quotes through `vm ssh` has opened WinMux's Config Error window.
- A Lens remembers its Search for the life of the process. Restart the debug build between takes whose Search must start empty.
- `overview` draws a workspace not yet shown since WinMux started at remembered positions, which can be wrong, tab-group fans included, until **Overview draws a workspace not yet shown at the wrong positions** lands. After every start of a build, show each workspace once, go back to the starting one, and wait for pictures before a take.
- A floating window an app reshapes after WinMux sees it can draw at an 800 by 600 fallback shape in a Lens, until **Floating picture Tiles fall back after an app resizes its windows** lands. Before a take of `stage.swift` or other app-reshaped floating windows, run `winmux agent query --path <file>` once, which reads every native frame, wait two seconds, and check the Tile widths differ as the windows do.
- A claim that is a static state gets a **still**.
- A claim that is a command's output (JSON, an exit code, a `config check` result) gets a **transcript**: the command and its real output in a code block.
- Order by story: one **hero** first, showing the feature doing its main job; then groups under plain headings (everyday use, configuration, when something fails, CLI), each opened by one sentence; then the table mapping every Done-when item to its demos.

Done when every Done-when item appears in the table against a demo, still or transcript, or against the reason it cannot be shown, and each demo has its claim, setup, action, what to watch, and crop.

## 2. Get the storyboard checked

Hand the storyboard to whoever asked for the demos before filming. Filming a bad plan well is wasted work.

Done when they have accepted it or you have applied their changes.

## 3. Stage and film each take

Film in a guest from the `vm` skill, on the build of the commit the pull request will merge.

Stage the desk like a flat being shown: real apps doing plausible work, each different enough in look that "the terminal landed in Column 3" reads at a glance. The apps are real and every word on screen is ours. Jokes live in that content (a window title, a to-do list, a commit message) and never in what WinMux is shown doing. Push `desk/` to `~/desk` with `vm push`; one push supplies both sets. `desk/stage-desk.sh` dresses the standing set (Zed, Ghostty, Safari and Notes on two workspaces, with `desk/Updater` as the dialog that is not yours). Use it for a focused behavior demo. It serves `docs/lenses.md` at localhost for Safari, without its demo GIFs: their captions show as text between the opening paragraph and the Lens table, which takes filmed before the hero demos did not show. It lists exactly four windows, and checks both workspaces for extra CoreGraphics windows, AX sheets and first-run text that Zed does not expose through AX. A stranger is named and staging exits non-zero.

`desk/stage-rich.sh` dresses the fourteen-window Lens set on four workspaces, with Columns, tab groups and a floating Calculator; use it at 1920 × 1080 for Tile geometry and comparisons with the Lens look prototype. It stages on its first run in a fresh guest and fails naming a missing or extra window. Its config and text files are under `desk/rich/`; it compiles its tools, opens the real apps, and reads the local Notes list through the image’s granted Notes Automation and waits for its window title to match the note count, preserving existing note content. It uses no Safari Automation or window-creation keystrokes. Each readiness wait is bounded at 60 seconds (`STAGE_RICH_TIMEOUT` overrides it); the script checks the display size, process exit, windows, workspace and Column membership, and the exact final inventory by app, title, workspace and layout. The image handles Notes onboarding, Ghostty updates, close confirmations and registration, Zed trust and its Delta announcement, widgets, wallpaper tips and notifications. Both sets copy the Zed settings, `session.trust_all_worktrees` included, from the synced tree's `.claude/skills/vm/guest/zed-settings.json` on each stage, so a branch that edits them stages with its own; a tree from before that file existed falls back to the image's copy in `~/vm`. Done when it prints fourteen windows and the Columns on workspaces 2 and 3. Until **The standing desk does not stage after the rich desk in the same guest** lands, film the standing set before the rich set in a guest, or take a fresh clone for it. `stage.swift` puts up plain coloured windows for claims that need controlled shapes or many identical ones.

For a demo that wants an extra prop, run `~/desk/props calendar` or `~/desk/props music` after staging. Calendar replaces the local `Desk` calendar's events with today's four appointments and shows Day view with only Desk checked. Music's cold-library welcome resists scripted setup, so its prop opens the album and track lines in a separate Zed workspace, reusing it on the next run. Each prop leaves one readable floating window on the focused workspace. Restaging closes both; the standing set stays four windows on two workspaces.

After a take that fixes a grievance, run `~/desk/strike <n>` (1 to 5) to strike that line in the Notes note **Grievances**. Earlier strikes remain. `~/desk/strike reset` restores all five before another take; staging also resets them. The rich set's TextEdit file is separate.

Film the standing set on a 16:9 guest display at 1280 × 720; keep the rich set at 1920 × 1080. Push `keys.swift` and `film` into the guest beside the desk, compile `keys`, and film each take there:

```sh
~/desk/film <id> <seconds> down:cmd tap:tab wait:1.0 tap:tab wait:1.3 up:cmd
```

`film` records the screen while `keys` presses the steps, starting 1.5 seconds in and logging each chord's time to `<id>.events.json`, so every take opens on a held starting state and the key chips land where the keys did. Leave two seconds of recording after the last step for the result. Park the pointer near the bottom-right corner first, at `cliclick m:1240,714` on a 1280 by 720 guest, in the margin below the windows and not in the corner itself: the exact corner is macOS's Quick Note hot corner, which draws a white page fold into the take, and a point inside a window can raise a tooltip, as `1250,690` does over Zed's status bar on the standing desk.

- **A take of a system shortcut on Control-arrow** (Mission Control, App Exposé) cannot use `keys`, which drops the Function flag the system needs; see the `vm` skill. Give `film` only a `wait:` step, start `arrow-chord` in the background at the chord's time, and write that take's `events.json` by hand from the time the overlay starts in the take, so its key chip lands there.
- **`keys` steps** are `down:`, `up:`, `tap:`, `wait:` and `delay:`. Escape is `tap:escape` and Backspace is `tap:backspace`; digits are `tap:3`, and the square brackets `tap:leftbracket` and `tap:rightbracket`. It logs taps only, so a take of a modifier alone has an empty event log.
- **Workspace names follow the sidebar's order.** WinMux names a workspace by where it sits in the sidebar, so a take that moves a window between workspaces can reorder the sidebar and renumber them, and every label that names a workspace follows. Before a take, check the sidebar reads 1 above 2 as the storyboard expects, and restart and restage when it does not.
- **Every take starts clean**: no Lens open (`winmux debug-lens-trace --last 1` shows no active session), the pointer parked, and the workspace and focus the storyboard names.
- **A Lens opened from the CLI stays open, a strip included.** Only a held chord commits on release, and only on a Lens whose `on-release` resolves to `'commit`: hold the modifier through `keys` to film a committing Lens.
- **Wait for pictures.** A window just staged or opened draws as its app icon until its first capture lands.
- **A take that types** is read back with `winmux debug-lens-trace`, which prints the keys and a `Session:` line (Search, selection, Presentation, Hold) under each opening.
- **A claim about when the first frame appears** is filmed with `$SKILL/trace-film` and checked with `check-lens-film.py`, as `docs/lens-opening-traces.md` says. The checker compares presented openings only: it rejects a take in which nothing draws, such as a quick tap that commits before the first frame, with "the event log has no openings to compare". Check that kind of take by reading every frame and the trace's "cancelled before first frame" line, and say so in the caption. Film it first, before anything reboots or resizes the guest.

After each take, read back where WinMux ended (`winmux list-workspaces --focused`, `list-windows --focused`, `list-windows --all`) and compare it with the storyboard's **Watch**. A take can look right and be wrong: a window that slid behind another looks closed.

Done when every demo in the storyboard has a take whose last frame shows the result its claim names, and an event log.

## 4. Render

```sh
$SKILL/render <take> -o $OUT/demos/<id>.gif --title "<the claim in a few words>" \
  --crop <x:y:w:h> --start <s> --end <s> --events <take>.events.json
```

A `screencapture` take has a variable frame rate, and `render` seeking into one can give blank opening frames: make a constant-frame-rate copy first. At 1920 by 1080 a whole-screen GIF comes out at 960 by 604 and about 1 MB at the 15 fps render; crop to the panel where the claim allows it.

`--width <pixels>` scales the whole card; it accepts even widths from 320 to 1920. The default is 960, which remains the width for pull-request demos. Use 1280 for a larger exported card.

Every demo is a card: the take with rounded corners on a dark gradient, the claim above it and the keys below. Crop when the subject is small in the frame. `render` refuses a demo over 8 seconds or 3 MB: a claim that needs longer is two claims, and one that needs more pixels wants a tighter crop.

Done when every demo renders inside the budget.

## 5. Check every demo

Read frames of each GIF at its start, at each key chip, and at its end. Check that the result is on screen and held, that the title and keys are legible, and that nothing shows a username, a home path, a machine name, an IP address or a window that is not staged. The guest's own `admin` and `winmux-vm` are fine.

Done when each demo passes the viewer test above from its caption and one loop alone.

## 6. Write the captions

Above each demo in the pull request description, three short lines: the **claim**, the **setup** ("three windows on workspace 2, Columns at 3"), and what to **watch** ("the blue window lands in Column 3"). Attach the GIFs with `gh attach --repo prateek/winmux`; the flag is `--repo`, and `-R` is rejected. It uploads and prints the URLs, and posts nothing unless asked.

Done when the description has the hero, the groups, each demo under its caption, and the Done-when table.
