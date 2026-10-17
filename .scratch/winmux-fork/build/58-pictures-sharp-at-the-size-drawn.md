# A picture as sharp as the Tile that draws it

Part of {{UMBRELLA}}.

## What to build

The original cache saved each window's picture at most 582.4 points wide: the 560-point workspace width of `'miniatures`, plus 4%, at the display's scale (`ThumbnailCache`). That was the largest any Presentation drew when the cache was built.

A grid of few windows draws larger Tiles. In the checked three-window grid at 1920 by 1080, a selected Tile's picture is 613.1 points wide, and the grid's row height grows with the monitor, so an ultrawide stretches the same 582-point picture much further. The stretched picture is blurred: text in it cannot be read.

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

- [x] A three-window grid at 1920 by 1080 shows each live window's picture at one image pixel per screen pixel or better; a still beside the current build shows the difference.
- [x] A forty-window grid captures no window larger than it draws it.
- [x] No capture is larger than its window.
- [x] Opening a Lens still fetches nothing before its first frame; the opening trace is unchanged within noise.
- [x] The pull request has WinMux's memory with forty windows, before and after.

## Built and checked

Every Presentation sends its fitted picture size × the Lens screen’s backing scale; the grid and the strip, which enlarge the selected Tile, also multiply by its 1.045. Each open Lens token owns a demand; captures cover the largest demand while preserving the capture frame’s aspect and respecting the window’s own screen-pixel cap. A capture made outside a Lens's own refresh (parking, focus loss, minimize) never goes below the original size, so a small Presentation cannot shrink the picture a window parks with; it too is subject to the window cap. Frozen guards, Peek and startup preparation are unchanged.

At 1920 × 1080 and backing scale 1, the selected text picture draws at 613.1 × 309.7 pixels: the base captures 583 × 295, the new build 614 × 310. Lossless 1:1 comparison stills were checked. Forty varied-shape live windows on one workspace capture at their selected picture demands; the largest is 190 × 99 rather than the base’s 583 × 617. A selected 180 × 120 native window is capped at exactly 180 × 120 despite a 188.1 × 125.4 demand.

Three-run physical-footprint medians, outside / open grid / five seconds closed, in MiB: three windows base 90.3 / 91.1 / 91.0, new 90.3 / 91.1 / 90.9; forty windows base 101.8 / 109.9 / 102.9, new 103.8 / 111.8 / 104.8. Smaller captures did not yield a measured total-footprint saving.

Five openings in each of three fresh processes per build give pooled trace medians of 97.0 ms base and 90.5 ms new (within 20 ms); film medians are 60.9 and 70.1 ms. The unchanged film checker flags late third-tick proxies on five base openings and one new opening. Preparation still requests no capture; the refresh launch path is unchanged. This diagnostic limitation is retained with both timing tables rather than changing the opening path.

A selected Frozen picture keeps 583 pixels of saved width against 613.1 drawn pixels. A future park-time capture at least 614 pixels wide would cover this setup; that change remains a question for Prateek and is not built.

The injected-cache, gate, cap and all four Presentation seams have regressions, including retaining a larger in-flight follow-up and keeping minimization waiting for the size it requested. Host and pinned-version guest `make check` pass. The same no-demand regression passes on the pinned base tree. No chosen default changed.

## Checks for Prateek

- [ ] Installed-build behavior and CI on swift.org’s toolchain.
- [ ] A Retina or ultrawide display.
- [ ] A second display and physical movement between displays.
- [ ] Real sleep, wake and unlock.

## Sources

- Pull request [#82](https://github.com/prateek/winmux/pull/82), **Decisions the relay made**: "The thumbnail cache's width cap stays".
- Prateek, 2026-10-05: "can't we take better pictures?"
