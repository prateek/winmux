# Summon's landing outline ignores the window's minimum width

Part of {{UMBRELLA}}.

## What to build

The landing outline a Lens draws while Summon hints show can be smaller than the window that then lands there. In the hero demos' Summon take (pull request #170, `docs/demos/summon-landing.gif`), on the standing desk at 1280 × 720 with Columns off, the strip selected Safari on workspace 2 and Option drew the outline on workspace 1 as the third horizontal tile beside Zed and Ghostty, about a third of the screen wide. After Option-Return, Safari landed at the outline's origin but kept its 574-point minimum width, so it ran past the outline and off the right edge of the screen. `list-windows --workspace 1` then listed Zed, Ghostty and Safari.

The outline comes from the same read-only decision as `winmux place --dry-run` (`docs/columns.md`, Column commands). That decision gives the tile's frame; the window's own minimum size is not part of it, so the preview and the result differ for any window whose minimum is larger than its tile.

## Decisions

- **The outline shows where the window will be.** When the window cannot shrink to its tile, the outline shows the frame the window will actually take, or the Lens says it will not fit; it never shows a smaller frame than the one that lands.

## Not in this issue

- Changing how tiling lays out a window whose minimum width exceeds its tile.
- Floating Summon previews, which keep the window's own frame already.

## Depends on

Nothing.

## Done when

- [ ] A test through the landing decision gives, for a window whose minimum width is larger than its tile, an outline no smaller than the frame the window takes after Summon.
- [ ] In a guest, the hero Summon take (`docs/demos/storyboard.md`, `summon-landing`) shows an outline that matches Safari's landed frame, read back with `list-windows` and the window's frame.
- [ ] Windows that fit their tile show the same outline as before.
- [ ] `docs/demos/summon-landing.gif` is filmed again from the storyboard, and the caption in `docs/lenses.md` drops its note that Safari runs past the outline.

## Sources

- Pull request #170: the `summon-landing` take, its read-back, and the storyboard's note on Safari's minimum width.
