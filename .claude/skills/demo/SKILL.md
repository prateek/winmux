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

Stage the desk like a flat being shown: real apps doing plausible work, each different enough in look that "the terminal landed in Column 3" reads at a glance. The apps are real and every word on screen is ours. Jokes live in that content (a window title, a to-do list, a commit message) and never in what WinMux is shown doing. `stage.swift` puts up plain coloured windows for the claims that need many identical ones.

Film at 30 fps. Park the pointer bottom-right. Shape every take as **before, action, after**: hold the starting state for one second, perform the action, hold the result for two seconds. Write the take's event log beside it as you send each chord: `[{"t": <seconds from the start of the take>, "keys": "cmd tab"}]`.

Done when every demo in the storyboard has a take whose last frame shows the result its claim names, and an event log.

## 4. Render

```sh
$SKILL/render <take> -o $OUT/demos/<id>.gif --title "<the claim in a few words>" \
  --crop <x:y:w:h> --start <s> --end <s> --events <take>.events.json
```

Crop to the region the claim is about. The hero takes `--style card`; every other demo keeps the default tight crop over a title strip. `render` refuses a demo over 8 seconds or 3 MB: a claim that needs longer is two claims, and one that needs more pixels wants a tighter crop.

Done when every demo renders inside the budget.

## 5. Check every demo

Read frames of each GIF at its start, at each key chip, and at its end. Check that the result is on screen and held, that the title and keys are legible, and that nothing shows a username, a home path, a machine name or a window that is not staged.

Done when each demo passes the viewer test above from its caption and one loop alone.

## 6. Write the captions

Above each demo in the pull request description, three short lines: the **claim**, the **setup** ("three windows on workspace 2, Columns at 3"), and what to **watch** ("the blue window lands in Column 3"). Attach the GIFs with `gh attach --repo prateek/winmux`.

Done when the description has the hero, the groups, each demo under its caption, and the Done-when table.
