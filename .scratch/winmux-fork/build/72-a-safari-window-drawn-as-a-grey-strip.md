# A Safari window's picture is a thin grey strip

Part of {{UMBRELLA}}.

## What to build

On the staged desk in `0.5.6-dogfood.13`, one Safari window's Tile showed a thin grey strip in place of the page, in every grid capture.

Inferred, not shown: the capture took a 913 by 16 helper window of Safari's in place of the page's window.

## Decisions

- **Reproduce first**, and say which window the picture came from.
- **A Tile's picture is of the window the entry stands for.**

## Not in this issue

- How sharp a picture is. That is **A picture as sharp as the Tile that draws it**.

## Depends on

Nothing.

## Done when

- [ ] Every Safari window on the staged desk draws its page in a grid and in a strip.
- [ ] A test covers choosing the window to capture when an app has a helper window of the same owner.

## Sources

- The switching comparison, 2026-10-07: the grid captures by workspace, by app and with no sections.
