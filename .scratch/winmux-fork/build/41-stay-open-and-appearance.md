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

- [x] A grid Lens with `on-release = 'commit`, opened by a held chord, steps on the invoking key and commits on release.
- [x] A strip with `on-release = 'stay` stays open after release and commits on Enter.
- [x] A quick tap on a committing grid switches without drawing and emits no Lens events, as the strip does.
- [x] With the system in light mode a Lens draws light; `appearance = 'dark` keeps it dark.
- [x] The pull request shows the strip, the grid and the list in both appearances.

## Sources

- [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html), the Theme switch.

## Built

`on-release` and `appearance` are optional contract fields, including in `when.default`. Unset release resolves in Swift after the opening Presentation override; no shipped Lens sets either field. The opening and session share the held-commit predicate, while strip/grid/list/miniatures retain their own layouts. A list conversion ends committing; a Hold ended by a key never commits on the later release. A committing release clears peek immediately, and a staying release preserves zoom.

A chord needs a key and held modifiers. CLI, tap, menu and modifier-free openings stay open, including strips. This deliberately changes the old CLI strip, which committed without drawing. Repeating a named staying strip's invoking chord after release toggles it closed, matching a grid. Shift-only committing chords wait for Shift release.

The theme is snapshotted once per opening through a test seam, applied to the native panels and shared through SwiftUI's environment. Light uses the prototype's pale fill over blur, or an opaque pale panel with solid chrome; dark retains the existing glass recipe. The selection keeps the system accent colour in both. The hint legend, and the labels drawn over window pictures, keep their dark plate and white text. Pictures, app icons and Frozen treatment remain unchanged. Miniatures uses the same darkness opacity over black or pale grey; peek retains its 28% dimming.

Baseline seam tests pass before the split. Host and pinned-toolchain guest checks cover the optional fields, defaults/profiles, held and no-chord paths, step/reverse, release actions, silent quick taps, conversion, letters, peek and appearance snapshots. Owned-window live readbacks cover the first four Done-when items, six Presentation/appearance combinations, forced dark under a light system, light peek and miniatures, and native Cmd-Tab ownership. The same unchanged-action script passes against the actual base tree and the feature tree. PR media is checked separately from the final commit in the demo pass.

## Owner checks

A quick tap and a held chord on a real keyboard, and both appearances on an installed build, are in **Prateek's checks on an installed build and real hardware**.
