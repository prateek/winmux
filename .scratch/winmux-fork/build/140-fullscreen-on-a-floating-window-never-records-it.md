# `fullscreen` on a floating window never records it

Part of {{UMBRELLA}}.

## What to build

`winmux fullscreen`, by `--window-id` or on the focused window, grows a floating window to the full panel and exits 0, but the window's `winMuxFullscreen` stays false, so the next call grows it again instead of restoring it. Tiled windows toggle correctly.

To see it: open any window that floats, shrink it to 800 by 500, run `winmux fullscreen` twice, and read the frames with `winmux agent query`: the second call restores nothing.

## Decisions

- **A floating window records fullscreen as a tiled one does**, with its previous frame, so the second call restores that frame.
- **`fullscreen --no-outer-gaps` and `layout floating tiling`** keep their current meaning for a fullscreen floating window: leaving floating clears the record and tiles the window.

## Depends on

Nothing.

## Done when

- [ ] A test floats a window, runs `fullscreen` twice and asserts the original frame is back and the record is false.
- [ ] In a guest, the reproduction above restores the window on the second call, read back with `agent query`.

## Sources

- #268's handoff, "Fullscreen on floating windows is one-way", with the reproduction.
