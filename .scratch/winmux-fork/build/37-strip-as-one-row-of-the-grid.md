# The strip as one row of the grid

Part of {{UMBRELLA}}.

## What to build

Every strip, Cmd-Tab included, shows every window using `GridLayout`. Tiles grow to the largest fitting single row, then wrap into the fewest readable rows. Selection changes reuse cached frames; no entry is hidden behind a count, scrolling or paging.

## Decisions

- **One row, sized to fit.** The strip uses the grid's sizing with a single row. Three windows grow to the cap; each row uses the largest height its width allows.
- **When one row cannot hold them all at a readable size, the strip wraps to more rows.** It does not count the overflow as "+N" and does not scroll.
- **Everything the strip does today stays**: the held-modifier gesture, commit on release, the delay before it draws, the step on the invoking key, conversion to the list, and the events.
- **The strip ignores `sections`.**

## Not in this issue

- A setting for what release does, which is **Staying open on release, and light and dark**.
- Any change to cmd-tab ownership or to the Triggers.

## Depends on

- **The `'grid` Presentation: every match at once, sized to fit**.

## Defaults chosen for you

- **The readable size.** 88 scaled points, measured from the prototype's fourteen-picture, real-size strip. Cards retain the grid's title-width floor and can wrap sooner. When readable rows cannot fit vertically, the grid's shrink policy fits every Tile.
- **The row height cap.** 190 scaled points, the prototype's cap. Two windows stop there.
- **`StripLayout`** is removed; its gesture, list layout and session extension stay. `StripSnapshot` calls `GridLayout` with strip chrome and a selection-independent cache.

## Done when

- [x] A strip with three windows draws larger Tiles than a strip with nine.
- [x] A strip with fourteen windows shows all fourteen, with no "+N".
- [x] Hold, step, reverse with shift, release to commit and Escape behave as before, checked in a guest with the `keys` driver.
- [x] A quick tap that never draws still emits no Lens events.
- [x] The pull request shows the strip at three, nine and fourteen windows.

## Built behavior

The strip honours `grid.tile-size`, including the default `'real`, and ignores `grid.sections-arrangement`. Fit sizing keeps the existing config spelling `'same-height` and the grid's 0.6–2.1 aspect limits. `accessory-window` retains its strip meaning in every size mode; the grid keeps ignoring it. Every non-Frozen strip picture joins the existing 500 ms refresh.

Left/right, Tab, backtick and the invoking key still step in ranked order and wrap. Up/down cycle in a single row; in wrapped strips they choose the nearest Tile above/below and stop at the outer rows. The Hold, delay, release, initial selection, letter conversion, clicks, Summon and events retain their existing lifecycle.

## Checks for Prateek

- [ ] Installed/release build.
- [ ] A real keyboard and a second display.
- [ ] Real sleep, wake and unlock.

## Sources

- [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html), Presentation set to Strip.
