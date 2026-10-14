# Floating picture Tiles fall back after an app resizes its windows

Part of {{UMBRELLA}}.

## What to build

A floating window's Tile takes its shape from `thumbnailCaptureFrame`, which reads `lastKnownActualRect`, then `miniatureFrame`, then an 800 by 600 fallback. Move and resize events invalidate the actual-frame cache. The floating-window refresh path is meant to re-warm it, but an app reshaping many windows can leave it absent when a Lens snapshots its Tiles.

In the controlled twenty-five-window fixture, the app creates windows, WinMux makes them floating, and the app reshapes them to 600-point height with aspects cycling through 0.3, 0.45, 0.7, 0.8, 0.9, 0.6 and 2.6. Three seconds later, the first picture strip uses near-uniform width allocations. A subsequent `agent query` followed by another strip opening gives varied allocations and a taller two-row panel.

A temporary diagnostic at `tileEntry` confirmed twenty of the twenty-five windows had `lastKnownActualRect = nil` and `miniatureFrame = nil` at the cold snapshot, so their capture frames were 800 by 600. For example, window 1858 used that fallback although its native frame was 180 by 600; window 1859 was 270 by 600. The next snapshot after the query had the native frames. No stale non-nil actual rectangle was observed. This is an absent-cache fallback, not proof that resize invalidation itself is missing. The diagnostic was removed; no behavior fix was made.

## Decisions

- **A picture Tile opened after an app resizes a floating window uses the window's current native shape**, without needing an `agent query` first.
- **Opening the Lens does not move or resize those windows.**

## Not in this issue

The strip's row rule, Tile size policy, thumbnail sharpness and global polling of every native frame.

## Depends on

Nothing.

## Done when

- [ ] A regression creates floating windows, invalidates their native frames through app-driven resize events, and opens a picture Lens without a native-frame query; the Tile aspects match the resized frames.
- [ ] The cold and query-warmed openings of the twenty-five-window controlled fixture allocate the same Tile widths and panel geometry to within a point.
- [ ] Native frames are unchanged by both openings.
- [ ] Refresh and snapshot callers share one native-frame observation path, with existing generation checks preserved; no global per-refresh polling is added.

## Sources

- Pull request [#149](https://github.com/prateek/winmux/pull/149), second builder pass: cold/warm screenshots, native CoreGraphics inventory and temporary `tileEntry` frame-probe transcript.
- `Sources/AppBundle/ui/hud/SwitcherPalette.swift`: `tileEntry` snapshots capture-frame shape.
- `Sources/AppBundle/lens/ThumbnailCache.swift`: `thumbnailCaptureFrame` and `captureFrame`.
- `Sources/AppBundle/layout/refresh.swift`: re-warming floating windows whose actual-frame cache is absent.
