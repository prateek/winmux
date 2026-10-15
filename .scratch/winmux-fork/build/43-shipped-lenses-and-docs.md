# Shipped Lenses for the grid, and the docs

Part of {{UMBRELLA}}.

## What to build

The grid exists after the issues before this one, and no shipped Lens uses it. This issue puts it in the default config and documents the Lens look as built.

## Decisions

- **A shipped Lens named `windows`** shows every window in a grid, grouped by workspace. It is the Mission Control replacement.
- **`app-windows` and `floating` become grids.** Their windows have no positions worth keeping. `app-windows` commits on release; its cmd-backtick Trigger is opt-in, as the Cmd-Tab issue decides.
- **`recent` stays a strip**, reached as **The system's Cmd-Tab stays the system's unless the config asks for it** decides, and **`overview` stays `'miniatures`**.
- **`windows` is in the `window` binding mode** on `w`.
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
- **`floating`'s sort** stays MRU.

## Done when

- [x] A fresh install opens `windows` from the `window` binding mode and shows every window grouped by workspace.
- [x] cmd-backtick opens a grid of the focused app's windows and commits on release.
- [x] `winmux list-lenses` lists six Lenses.
- [x] `docs/lenses.md` describes every new field, and each example in it loads.
- [x] The default-config tests cover the new Lens and the changed Presentations.

## Build and validation

- `windows` adds only a priority -1 grid Presentation; its Filter, MRU, workspace sections, card Tiles, real sizes and flow arrangement come from the contract. The `window` mode now has 44 keys and six Lens letters; `a` and `r` keep their explicit text-list overrides. Main ships no `windows` Trigger.
- `app-windows` explicitly commits on release and drops its strip-only picture/same-height settings. `floating` keeps its Filter, empty popups and existing MRU order; the title-sort Default above was a misdescription. No Swift Lens implementation or name special case was needed.
- Host and pinned Swift 6.2.4 guest `make check` pass, including six-Lens conversion, key removal, disabled/overridden defaults, the shipped same-app gesture and every whole-config Nickel example in `docs/lenses.md`. One existing fragment was wrapped as a config; no error-example fence was relabelled. Escape counts and the 48-point strip picture floor stay unchanged.
- The standing-desk live run checks fresh-install and import-only workspace grids against all four window IDs, plain/JSON six-Lens output, retained `a`/`r` text lists, a floated window in `floating`, held same-app stepping/reversal and release Focus, a silent quick tap, conversion and all four dark Presentation pictures. One unchanged-action script passes against the base and feature builds. The builder publishes no release.

## Sources

- **Default config, Triggers, the `lens` leader mode, `subscribe` events**, which shipped the first five Lenses.
- [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html)
