# A picture as sharp as the Tile that draws it

Part of {{UMBRELLA}}.

## What to build

WinMux saves each window's picture at most 582 points wide: the 560-point workspace width of `'miniatures`, plus 4%, at the display's scale (`ThumbnailCache`). That was the largest any Presentation drew when the cache was built.

A grid of few windows draws larger Tiles. With three windows at 1920 by 1080 a Tile's picture is 616 points wide, and the grid's row height grows with the monitor, so an ultrawide stretches the same 582-point picture much further. The stretched picture is blurred: text in it cannot be read.

Take the picture at the size it is drawn.

## Decisions

- **A picture is captured at the largest size any open Presentation draws it**, in pixels at that display's scale, and never larger than the window itself.
- **The cap that remains is the window's own size.** A window is never captured above its real pixel size, so memory is bounded by what is on screen.
- **Captures made outside a Lens stay small.** Parking, focus loss and minimize capture at today's size, since no Tile is asking. When a Lens opens and a Tile needs more than the saved picture has, that window is refreshed first at the needed size, and the saved picture is shown, stretched, until the new one lands.
- **A Frozen thumbnail cannot be retaken.** It keeps the size it was saved at. So a window that is not on screen stays as sharp as its last capture; the pull request says what a Frozen Tile looks like in a three-window grid and whether the park-time capture should be larger to cover it.
- **Memory is measured**, with forty windows, before and after.

## Not in this issue

- Paging the grid, or a Tile that collapses to text.

## Depends on

Nothing. **The grid's first opening, and what refreshing every Tile costs** measures the same captures; build that one first if both are open.

## Defaults chosen for you

- **Where the size comes from.** A Presentation already passes its session token for live refreshes. It passes the drawn pixel size with it.

## Done when

- [ ] A three-window grid at 1920 by 1080 shows each live window's picture at one image pixel per screen pixel or better; a still beside the current build shows the difference.
- [ ] A forty-window grid captures no window larger than it draws it.
- [ ] No capture is larger than its window.
- [ ] Opening a Lens still fetches nothing before its first frame; the opening trace is unchanged within noise.
- [ ] The pull request has WinMux's memory with forty windows, before and after.

## Sources

- Pull request [#82](https://github.com/prateek/winmux/pull/82), **Decisions the relay made**: "The thumbnail cache's width cap stays".
- Prateek, 2026-10-05: "can't we take better pictures?"
