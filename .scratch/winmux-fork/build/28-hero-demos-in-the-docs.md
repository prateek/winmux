# Hero demos in the README and the docs

Part of {{UMBRELLA}}.

## What to build

The README shows upstream's screenshots and says nothing a reader can watch about what the fork adds. `docs/lenses.md` and `docs/columns.md` are text and Nickel examples. This issue films a small set of hero demos on the staged desk with the `demo` skill and puts them at the top of those three pages, so a reader sees the strip, the overview, Search and Columns working before reading how to configure them.

## Decisions

- Every demo is filmed in a guest with the `demo` skill, from a storyboard written first, on the commit of `fork` the pull request branches from.
- The format is the pull request demos': a 16:9 guest display at 1280 × 720, each demo a card with its claim above and key chips below, 15 fps, at most 8 seconds and 3 MB.
- One demo per claim. A page gets the few claims that explain the feature, not one for every setting.
- The set is the staged desk: real apps doing plausible work, every word on screen ours, jokes in that content only.
- The GIFs are committed to the repository, so the pages do not depend on an attachment's URL.
- Each demo sits above a one-line caption stating its claim, and has alt text that says what happens in it.

## Not in this issue

- A demo for every Done-when item of the foundation's issues. Those are on their pull requests.
- A video with sound, zooms or cursor effects.
- Rewriting the pages' text beyond what placing the demos needs.
- `docs/default-config.md` and `docs/events.md`. They are reference pages with nothing moving.

## Depends on

- A fresh guest stages the desk with no first-run screens
- Calendar and Music on the set, a grievance struck out, and a `render` width

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **Which claims.**
  - README: one hero, holding cmd and tapping tab to move between windows on two workspaces, and one Columns demo, a new window landing in an empty Column.
  - `docs/lenses.md`: the strip hero again; the `overview` Lens opening on every workspace and Enter focusing a window; `alt-slash`, typing two letters and Enter; Summon with its landing outline.
  - `docs/columns.md`: a new window landing in the nearest empty Column; `column-width next` stepping through the Width presets; `move right` joining an occupied Column; a `place` hook sending a terminal to Column 3.
- **Where the files live.** `docs/demos/<id>.gif`, referenced by a relative path.
- **Where on the page.** In the README, a section for the fork placed above upstream's feature list. In the two docs, straight under the title and the opening paragraph.
- **Columns on a 16:9 guest.** Three Columns at 1280 × 720. Crop to the workspace if the text is too small to read.
- **The struck-out grievance.** The strip hero ends its take with "Alt-tab is a slot machine" struck out.
- **Total weight.** Keep the committed demos under 12 MB together.

## Done when

- [ ] The storyboard lists each demo with its claim, setup, action, what to watch and crop.
- [ ] The README shows the two demos, each under its caption, and they play on the repository's front page.
- [ ] `docs/lenses.md` shows its four demos and `docs/columns.md` its four, each under its caption.
- [ ] Every demo passes the `demo` skill's check: the result is on screen and held at the end, the title and keys are legible, and nothing shows a username, a home path, a machine name or a window that is not staged.
- [ ] After each take, what WinMux reported matches the storyboard's **Watch**.
- [ ] Every GIF is within 8 seconds and 3 MB, and the committed demos total under 12 MB.
- [ ] The Nickel examples in the docs still pass `winmux-nickel check`.

## Sources

- Pull request [#34](https://github.com/prateek/winmux/pull/34), which added the `demo` skill and the set.
- [`.claude/skills/demo/SKILL.md`](https://github.com/prateek/winmux/blob/fork/.claude/skills/demo/SKILL.md) and [`.claude/skills/demo/storyboard.md`](https://github.com/prateek/winmux/blob/fork/.claude/skills/demo/storyboard.md)
- [`docs/lenses.md`](https://github.com/prateek/winmux/blob/fork/docs/lenses.md) and [`docs/columns.md`](https://github.com/prateek/winmux/blob/fork/docs/columns.md)
