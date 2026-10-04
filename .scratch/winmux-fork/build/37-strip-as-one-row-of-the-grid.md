# The strip as one row of the grid

Part of {{UMBRELLA}}.

## What to build

The strip shows at most nine fixed cells and counts the rest as "+5" (`StripLayout` in `Sources/AppBundle/lens/StripLayout.swift`). It never grows: with three windows the cells are as small as with nine. This issue makes the strip the grid held to one row, so its Tiles are as large as one row allows and every window is in it.

## Decisions

- **One row, sized to fit.** The strip uses the grid's sizing with a single row. Three windows are large; twelve are smaller.
- **When one row cannot hold them all at a readable size, the strip wraps to more rows.** It does not count the overflow as "+N" and does not scroll.
- **Everything the strip does today stays**: the held-modifier gesture, commit on release, the delay before it draws, the step on the invoking key, conversion to the list, and the events.
- **The strip ignores `sections`.**

## Not in this issue

- A setting for what release does, which is **Staying open on release, and light and dark**.
- Any change to cmd-tab ownership or to the Triggers.

## Depends on

- **The `'grid` Presentation: every match at once, sized to fit**.

## Defaults chosen for you

- **The readable size.** The row height below which the strip wraps is the builder's call, starting from the prototype's strip at fourteen windows.
- **The row height cap.** A strip with two windows does not fill the monitor. The prototype's cap is the starting point.
- **`StripLayout`** goes, or becomes a thin call into the grid's layout. Its tests move with it.

## Done when

- [ ] A strip with three windows draws larger Tiles than a strip with nine.
- [ ] A strip with fourteen windows shows all fourteen, with no "+N".
- [ ] Hold, step, reverse with shift, release to commit and Escape behave as before, checked in a guest with the `keys` driver.
- [ ] A quick tap that never draws still emits no Lens events.
- [ ] The pull request shows the strip at three, nine and fourteen windows.

## Sources

- [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html), Presentation set to Strip.
