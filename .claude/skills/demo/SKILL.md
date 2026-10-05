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
- A claim that is a static state gets a **still**.
- A claim that is a command's output (JSON, an exit code, a `config check` result) gets a **transcript**: the command and its real output in a code block.
- Order by story: one **hero** first, showing the feature doing its main job; then groups under plain headings (everyday use, configuration, when something fails, CLI), each opened by one sentence; then the table mapping every Done-when item to its demos.

Done when every Done-when item appears in the table against a demo, still or transcript, or against the reason it cannot be shown, and each demo has its claim, setup, action, what to watch, and crop.

## 2. Get the storyboard checked

Hand the storyboard to whoever asked for the demos before filming. Filming a bad plan well is wasted work.

Done when they have accepted it or you have applied their changes.

## 3. Stage and film each take

Film in a guest from the `vm` skill, on the build of the commit the pull request will merge.

Stage the desk like a flat being shown: real apps doing plausible work, each different enough in look that "the terminal landed in Column 3" reads at a glance. The apps are real and every word on screen is ours. Jokes live in that content (a window title, a to-do list, a commit message) and never in what WinMux is shown doing. Push `desk/` to `~/desk` with `vm push`; one push supplies both sets. `desk/stage-desk.sh` dresses the standing set (Zed, Ghostty, Safari and Notes on two workspaces, with `desk/Updater` as the dialog that is not yours). Use it for a focused behavior demo. `desk/stage-rich.sh` dresses the fourteen-window Lens set on four workspaces, with Columns, tab groups and a floating Calculator; use it at 1920 × 1080 for Tile geometry and comparisons with the Lens look prototype. Its config and text files are under `desk/rich/`; it compiles its tools and opens the real apps without AppleScript Automation. First-run screens are handled by the guest image's setup. Done when it prints fourteen windows and the Columns on workspaces 2 and 3. `stage.swift` puts up plain coloured windows for claims that need controlled shapes or many identical ones.

Film on a 16:9 guest display, 1280 × 720. Push `keys.swift` and `film` into the guest beside the desk, compile `keys`, and film each take there:

```sh
~/desk/film <id> <seconds> down:cmd tap:tab wait:1.0 tap:tab wait:1.3 up:cmd
```

`film` records the screen while `keys` presses the steps, starting 1.5 seconds in and logging each chord's time to `<id>.events.json`, so every take opens on a held starting state and the key chips land where the keys did. Leave two seconds of recording after the last step for the result. Park the pointer in the bottom-right corner first.

After each take, read back where WinMux ended (`winmux list-workspaces --focused`, `list-windows --focused`, `list-windows --all`) and compare it with the storyboard's **Watch**. A take can look right and be wrong: a window that slid behind another looks closed.

Done when every demo in the storyboard has a take whose last frame shows the result its claim names, and an event log.

## 4. Render

```sh
$SKILL/render <take> -o $OUT/demos/<id>.gif --title "<the claim in a few words>" \
  --crop <x:y:w:h> --start <s> --end <s> --events <take>.events.json
```

Every demo is a card: the take with rounded corners on a dark gradient, the claim above it and the keys below. Crop when the subject is small in the frame. `render` refuses a demo over 8 seconds or 3 MB: a claim that needs longer is two claims, and one that needs more pixels wants a tighter crop.

Done when every demo renders inside the budget.

## 5. Check every demo

Read frames of each GIF at its start, at each key chip, and at its end. Check that the result is on screen and held, that the title and keys are legible, and that nothing shows a username, a home path, a machine name or a window that is not staged.

Done when each demo passes the viewer test above from its caption and one loop alone.

## 6. Write the captions

Above each demo in the pull request description, three short lines: the **claim**, the **setup** ("three windows on workspace 2, Columns at 3"), and what to **watch** ("the blue window lands in Column 3"). Attach the GIFs with `gh attach --repo prateek/winmux`.

Done when the description has the hero, the groups, each demo under its caption, and the Done-when table.
