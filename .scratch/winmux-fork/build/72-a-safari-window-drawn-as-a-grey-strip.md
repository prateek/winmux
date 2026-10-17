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

- [x] Every Safari window on the staged desk draws its page in a grid and in a strip.
- [x] A test covers choosing the window to capture when an app has a helper window of the same owner.

## Build

Capture chooses an SCWindow with a pure identity check. A plausible layer-0 window of the
entry's owner keeps its own id through normal size differences. If the id is missing,
nonzero-layer, or narrower or shorter than a quarter of the entry's actual frame, exactly
one other layer-0 window of the same owner must agree in x, y, width and height within
two points. Otherwise capture fails and retains the last good picture or icon. No actual
frame keeps id lookup. This uses `lastKnownActualRect`, never the layout-shaped capture
frame. Capture sizing, throttling, Frozen/minimized gates, minimize capture and the injected
id/size closure stay in place. Peek and flip snapshots carry the same identity.

Host and pinned-version guest `make check` pass: 1,432 Swift tests, helper suites and 138
script tests. New chooser and routing regressions fail with their fixes removed; existing
thumbnail and Peek tests are unchanged. No registration or window-heuristic change was
needed by the observed evidence.

The head live run also checks a Column-width change from 0.44 to 0.35 and a fresh Safari
picture, the single-match `Subscription` Search and Peek, and the two TextEdit faces of
the double-sided flip. The flip's focus readback changes to the other window. Its temporary
guest preference is restored and the debug app is quit after the run.

## Reproduction and live checks

The rich desk currently stages fourteen windows, including three Safari pages. All three
draw their pages in the grid by workspace, by app and without sections, and in the held
strip. A distinct new Safari URL also creates a page that draws in all four views. The
same guest script checks the base `3cfd54d2`, dogfood.13's `8e9ce664`, and this build.
Neither older build reproduces the grey strip. A separate 576-by-16 Safari window is
present, but no registered page uses its id; the original cause remains unproven.
Dogfood.13 does not log requested or returned pixel sizes and cannot keep a CLI-opened
strip visible, so its strip uses the same held Cmd-Tab action as the base/head comparison.

The standing desk is skipped after the rich desk while **The standing desk does not stage
after the rich desk in the same guest** remains unresolved. The proof tools and reproduction
instructions are in `.scratch/winmux-fork/proofs/safari-picture/`.

## Known consequence of the capture rule

The staged Updater dialog is a real layer-3 window. The required layer-0 rule rejects a
fresh capture of it, and no layer-0 window of its owner matches its actual frame. Its Tile
therefore shows an icon where the base showed its dialog. Other staged apps' layer-0
windows keep their own pictures. No exception to the settled layer rule is made here.

## Checks for Prateek

- [ ] Installed-build behavior.
- [ ] A second display.
- [ ] Real sleep, wake and unlock.

The builder publishes no release.

## Sources

- The switching comparison, 2026-10-07: the grid captures by workspace, by app and with no sections.
