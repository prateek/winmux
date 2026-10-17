# A strip with one entry per app draws badly

Part of {{UMBRELLA}}.

## What to build

A Lens with `entries = 'app` was captured as a strip in `0.5.6-dogfood.13` and has three faults.

- A card's title collapses to "…" behind its chips.
- A chip reads "1 windows".
- Ten apps fit one row at 164 by 117 points each. An eleventh wraps the strip to two rows and every Tile grows to 278 by 194.

## Decisions

- **The title is readable and the count is grammatical.**

## Not in this issue

- An icon-per-app Tile. It is under "Later, with no issue yet" in the umbrella.

## Depends on

Nothing.

## Defaults chosen for you

- **The jump at eleven** is the strip's row rule, fewest readable rows at the largest height, doing what it was built to do. Say in the pull request whether per-app entries should cap their height so a strip of apps holds one size.

## Done when

- [x] A per-app card on the staged desk shows its app name whole and its chips beside it.
- [x] One window reads "1 window".
- [x] The pull request shows ten and eleven apps before and after.

## How it was built

A per-app card reserves its bar's whole width in the strip and the grid: the icon, the app name at the selected weight (up to 240 points), and the chips, measured with the fonts of the layout's scale and capped at the row's or column's width. The reservation drops with the title floor when a layout has to shrink everything to fit. A marked per-app card draws its mark on the picture. Window-entry cards and picture and text Tiles are unchanged.

**The jump at eleven** stays: per-app entries get no height cap. On the rich desk at 1920 by 1080, wider cards wrap a strip of apps at seven, so ten and eleven apps both take two rows at one card size, where the base held them in one row.

## Sources

- The switching comparison, 2026-10-07: `entries = 'app` with cards, pictures and text at three, fourteen and twenty-five windows.
