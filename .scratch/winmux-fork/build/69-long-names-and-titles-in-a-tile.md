# Long names and titles in a Tile

Part of {{UMBRELLA}}.

## What to build

Two defects seen with titles of 80 to 95 characters on the staged desk, in `0.5.6-dogfood.13`.

- **A text Tile never truncates a long app name.** The name pushes the title out and runs across the neighbouring Tiles.
- **A card cuts its title at the tail**, near 16 characters at fourteen windows and near nine at twenty-five. Windows that share a prefix, such as pull requests of one repository, lose the part that tells them apart.

## Decisions

- **Text in a Tile stays inside the Tile.** A long app name is truncated.

## Not in this issue

- A wider panel for long titles.
- A change to the footer, which already shows the whole title.

## Depends on

Nothing.

## Defaults chosen for you

- **A title is cut in the middle**, keeping its start and its end, as the system's switcher and DockDoor do. Say so in the pull request if a tail cut reads better at some width.
- **The app name gives way before the title** when both cannot fit.

## Done when

- [x] A text Tile with a 92-character app name draws inside its own bounds, in a strip and in a list.
- [x] Two cards whose titles differ only after the twentieth character can be told apart at fourteen windows.
- [x] A layout or snapshot test covers both.

## Built

The title and app name share the space left by the icon, chips, mark and hint.
The app name gives way first, truncating at its tail down to one third of that
shared space. A short name keeps its natural width; the floor never widens it.
`TileBarTextLayout` measures the actual attributed SwiftUI Texts, including their
fonts, and calls the pure `tileBarTextWidths` allocation function.

Card bars, text Tiles and all list rows truncate titles in the middle. Footers,
section headers, the hint legend and peek labels retain their existing drawing.
A title that differs only in its hidden middle can still look identical.
Neither chosen default changed.

`TileTextTest` covers all four width-allocation cases, visible ink outside the
list and strip text-Tile frames, and differing card-bar pixels at the fourteen-window
size from `GridLayout`. Each fix was independently undone, its regression assertion
failed, and the fix was restored. Existing tests are unchanged. Host and pinned-version
guest `make check` pass: 1,397 Swift, 88 helper and 138 script tests each.

The same guest script checked base `72c6b9d5` and the changed build at 1920×1080:
three owned windows in list and text strip, fourteen in the card grid, and fourteen
title matches for Search `pr`. The long app name stays bounded, short app names
remain whole, card suffixes distinguish the windows and the retained title fragments
keep their highlights. The reproducible fixtures are in
`.scratch/winmux-fork/proofs/tile-text/`. The builder publishes no release.

## Checks for Prateek

- [ ] Check the installed build.
- [ ] Check a physical second display.
- [ ] Check real sleep, wake and unlock.

## Sources

- The switching comparison, 2026-10-07: long-title desks at three and fourteen windows.
- Prateek, 2026-10-07: "long titles" on his list from a day of use.
