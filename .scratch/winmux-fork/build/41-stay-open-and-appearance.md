# Staying open on release, and light and dark

Part of {{UMBRELLA}}.

## What to build

Two settings every Presentation takes.

- **What release does.** A strip commits when the held modifier is released. The other Presentations ignore the release and stay open. Which one happens is tied to the Presentation today. This issue makes it a setting, so a held chord can open a grid that commits on release, or a strip that stays open.
- **Light and dark.** A Lens is drawn dark. This issue draws it in the system's appearance.

## Decisions

- **`on-release`** is a Lens field: `'commit` or `'stay`. A strip defaults to `'commit`; the list, the grid and `'miniatures` default to `'stay`.
- **`'commit` on any Presentation** behaves as the strip does: opened by a chord with a held modifier, stepped by the invoking key, committed when the modifier is released. Opened any other way, there is nothing to release and it stays open.
- **`'stay` on a strip** keeps the strip open after release, until Enter or Escape.
- **`appearance`** is a Lens field: `'auto`, `'dark` or `'light`. The default is `'auto`, which follows the system.
- **Both appearances are designed.** The light one is the prototype's Light theme, not an inversion.

## Not in this issue

- A setting for the accent colour.
- Per-app or per-monitor appearance.

## Depends on

- **The strip as one row of the grid**.

## Defaults chosen for you

- **The gesture code** (`StripGesture` in `StripLayout.swift`) is already separate from the strip's layout. It becomes the thing `on-release = 'commit` turns on.
- **The delay before a committing Lens draws** stays the strip's, whatever the Presentation.
- **Appearance changes while a Lens is open** apply on the next opening.

## Done when

- [ ] A grid Lens with `on-release = 'commit`, opened by a held chord, steps on the invoking key and commits on release.
- [ ] A strip with `on-release = 'stay` stays open after release and commits on Enter.
- [ ] A quick tap on a committing grid switches without drawing and emits no Lens events, as the strip does.
- [ ] With the system in light mode a Lens draws light; `appearance = 'dark` keeps it dark.
- [ ] The pull request shows the strip, the grid and the list in both appearances.

## Sources

- [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html), the Theme switch.
