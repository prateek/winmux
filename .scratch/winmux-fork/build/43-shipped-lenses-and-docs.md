# Shipped Lenses for the grid, and the docs

Part of {{UMBRELLA}}.

## What to build

The grid exists after the issues before this one, and no shipped Lens uses it. This issue puts it in the default config and documents the Lens look as built.

## Decisions

- **A shipped Lens named `windows`** shows every window in a grid, grouped by workspace. It is the Mission Control replacement.
- **`app-windows` and `floating` become grids.** Their windows have no positions worth keeping. `app-windows` keeps its cmd-backtick Trigger and commits on release.
- **`recent` stays a strip** on cmd-tab, and **`overview` stays `'miniatures`**.
- **`windows` is in the `lens` binding mode** on `w`.
- **`docs/lenses.md`** documents the Tile, the grid, sections and the grouping control, hints, peek, `on-release` and `appearance`, with a picture of each Presentation.
- **`winmux config convert`** and the config examples are checked against the new fields.

## Not in this issue

- A trackpad gesture for `windows`. Gestures are deferred.
- The hero demos, which are **Hero demos in the README and the docs**.

## Depends on

- **Sections, and a control to change the grouping**.
- **Staying open on release, and light and dark**.
- **Hints shown while a key is held** and **Peek: see the selected window at full size before switching**, for their docs.

## Defaults chosen for you

- **A direct Trigger for `windows`.** None is shipped beyond the binding mode; ctrl-up belongs to Mission Control and taking it is Prateek's call.
- **`floating`'s sort** stays by title.

## Done when

- [ ] A fresh install opens `windows` from the `lens` binding mode and shows every window grouped by workspace.
- [ ] cmd-backtick opens a grid of the focused app's windows and commits on release.
- [ ] `winmux list-lenses` lists six Lenses.
- [ ] `docs/lenses.md` describes every new field, and each example in it loads.
- [ ] The default-config tests cover the new Lens and the changed Presentations.

## Sources

- **Default config, Triggers, the `lens` leader mode, `subscribe` events**, which shipped the first five Lenses.
- [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html)
