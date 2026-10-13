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

- [ ] A per-app card on the staged desk shows its app name whole and its chips beside it.
- [ ] One window reads "1 window".
- [ ] The pull request shows ten and eleven apps before and after.

## Sources

- The switching comparison, 2026-10-07: `entries = 'app` with cards, pictures and text at three, fourteen and twenty-five windows.
