# The strip draws pictures at one height

Part of {{UMBRELLA}}.

## What to build

The shipped `recent` strip draws a card per window at the windows' relative sizes. On a fourteen-window desk at 1920 by 1080 that is two rows, 54% of the screen's height, with fourteen truncated titles. Prateek: "i expected it to feel like cmd-tab -- it doesnt". The system's switcher is one row that never changes height and prints one name.

The shipped strips change to pictures at one height. It is the nearest to the system's proportions that still shows one entry per window.

## Decisions

- **`recent` and `app-windows` ship with `tile = 'picture` and `grid.tile-size = 'same-height`.** The selected window's title is in the footer, as today.
- **This answers two questions that waited on Prateek**: **Should a Cmd-Tab strip draw windows at their relative sizes?** (no, by default) and **Twelve windows in a strip draw larger than eleven** (pictures wrap near twenty windows, where cards wrapped at twelve).

## Not in this issue

- A change to `StripLayout`'s row rule or to `'real` sizing, which stay available to a config.
- An icon-per-app Tile.

## Depends on

Nothing.

## Defaults chosen for you

- **`app-windows`** takes the same two settings while it is a strip. **Shipped Lenses for the grid, and the docs** makes it a grid; that issue decides what it looks like then.
- **The footer** is unchanged.

## Done when

- [ ] On the staged desk with the shipped config, the `recent` strip is one row of fourteen pictures. In the comparison it measured 1730 by 202 points.
- [ ] Three windows and twenty-five windows are shown in the pull request beside it. They measured 506 by 298 in one row and 1730 by 384 in two.
- [x] `docs/lenses.md` and `docs/default-config.md` show the new defaults and how to get cards back.

## Build evidence and departures

Both shipped strips resolve to picture Tiles and `same-height` sizing. Plain card/real
overrides win, a partial `grid.sections-arrangement` override retains `same-height`, and
removing `recent` with the documented record operations loads. The windowing mode's `r`
and `a` use `--presentation list --tile text`; `/` and CLI conversion keep picture rows.
No Default chosen for you changed; the footer is unchanged.

The existing row rule does not reproduce the comparison sizes. Through `StripSnapshot`
at a 1920 by 1080 visible frame, the fourteen aspects in the Lens look prototype's `BASE`
fixture produce 1728 by 460.278 points in two rows. Even at the 88-point floor that row
needs 1940.834 points against the 1728-point limit. Three portrait windows produce
518 by 300 in one row; repeating the rich fixture to twenty-five produces 1728 by
605.324 in three rows. The controlled twenty-five-window fixture, with aspects spanning
0.3 to 2.6, produces 1728 by 368.504 in two rows. The row rule and `real` sizing remain
unchanged, as ruled; the first acceptance item stays unticked.

On the live staged desk at 1920 by 1080, with a 1920 by 1050 visible frame, fourteen
pictures occupy about 1728 by 494 points in two rows. The three-window panel is about
504 by 292 in one row. Twenty-five varied windows occupy about 1728 by 366 in two rows
after the native frame readback. Before that readback, twenty-five used three rows with
uniform allocations despite varied native frames; the cause remains unconfirmed. The
selected title, strip-to-picture-list conversion, text windowing lists, the same-app
picture strip and restoring the base card strip are checked live. One identical script
checks the base commit and the changed build. Host and pinned-toolchain guest checks pass.

The second acceptance item remains unticked: captures exist, but the pull request demos
belong to the driver, and the twenty-five-window height differs from 384 by more than 2%.

## Checks for Prateek

- [ ] Installed-build behavior.
- [ ] A second display.
- [ ] Real sleep, wake and unlock.

## Sources

- The switching comparison, 2026-10-07 to 2026-10-09: the system's Cmd-Tab, AltTab, DockDoor and the strip on the same desk in guests.
- Prateek, 2026-10-13, choosing among four looks: pictures at one height, one row.
