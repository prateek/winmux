# The strip draws pictures at one height

Part of {{UMBRELLA}}.

## What to build

The shipped `recent` strip draws a card per window at the windows' relative sizes. On a fourteen-window desk at 1920 by 1080 that is two rows, 54% of the screen's height, with fourteen truncated titles. Prateek: "i expected it to feel like cmd-tab -- it doesnt". The system's switcher is one row that never changes height and prints one name.

The shipped strips change to pictures at one height. It is the nearest to the system's proportions that still shows one entry per window.

## Decisions

- **`recent` and `app-windows` ship with `tile = 'picture` and `grid.tile-size = 'same-height`.** The selected window's title is in the footer, as today.
- **This answers two questions that waited on Prateek**: **Should a Cmd-Tab strip draw windows at their relative sizes?** (no, by default) and **Twelve windows in a strip draw larger than eleven** (pictures wrap near twenty windows, where cards wrapped at twelve).

## Not in this issue

- A change to `StripLayout`'s row rule or the `'real` size calculation. The row rule stays; picture Tiles in a strip at `same-height` or `equal` read at 48 scaled points; card and text Tiles, and pictures at `'real`, at 88.
- An icon-per-app Tile.

## Depends on

Nothing.

## Defaults chosen for you

- **`app-windows`** takes the same two settings while it is a strip. **Shipped Lenses for the grid, and the docs** makes it a grid; that issue decides what it looks like then.
- **The footer** is unchanged.

## Done when

- [x] On the staged desk with the shipped config, the `recent` strip is one row of fourteen pictures. In the comparison it measured 1730 by 202 points.
- [ ] Three windows and twenty-five windows are shown in the pull request beside it. They measured 506 by 298 in one row and 1730 by 384 in two.
- [x] `docs/lenses.md` and `docs/default-config.md` show the new defaults and how to get cards back.

## Departures

- Picture Tiles in a strip at `same-height` or `equal` use a 48-point readable floor; cards, text and `'real` pictures keep 88.
- The window mode's `r` and `a` use `--presentation list --tile text` to keep text rows.
- `/` and CLI conversion keep the Lens's picture rows; the cards-back recipe converts to card rows.
- Miniatures accepts `tile = 'picture` and rejects `card` and `text`, including in profiles.

## Checks for Prateek

- [ ] On an installed build with Cmd-Tab opted in, holding Cmd-Tab on his own desk draws one row of pictures at one height, with the selected title in the footer.

## Sources

- The switching comparison, 2026-10-07 to 2026-10-09: the system's Cmd-Tab, AltTab, DockDoor and the strip on the same desk in guests.
- Prateek, 2026-10-13, choosing among four looks: pictures at one height, one row.
