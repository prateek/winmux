# Peek: see the selected window at full size before switching

Part of {{UMBRELLA}}.

## What to build

A thumbnail answers "which window is this" most of the time. When two windows look alike at thumbnail size, the person has to switch to find out. Peek shows the selected window at its real size, in its real place, without switching to it. It is Quick Look for windows.

Prateek confirmed this design from the prototype on 2026-10-04.

## Decisions

- **A key zooms the selected Tile's picture out to the window's real frame.** The picture grows from where the Tile is to where the window is. The Lens dims behind it and stays open.
- **The same key, or Escape, puts it back.** The picture shrinks to its Tile.
- **While peek is up, the arrow keys move to the next entry**, and the peeked window changes with them, as Quick Look does in Finder.
- **Every other Lens key still acts on the selection**: Enter focuses it, `alt-enter` Summons it, `cmd-w` closes it.
- **Focus does not change.** Peek shows a picture of the window. It does not raise the window, move it, or switch workspace.
- **It works in every Presentation**, including `'miniatures`.
- **`peek` is a Lens action**, bound in the Lens's `keys` like `focus` and `summon`.
- **A second mode for a small panel.** `peek = 'follow` on a Lens shows the selected window under the panel all the time, moving as the selection moves, as AltTab does. It suits the strip and the list. It is off by default.
- **The look is the prototype's**: [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html). Click the desk and press Space.

## Not in this issue

- A live, updating peek. It is one picture.
- Interacting with the peeked window.
- Peeking a Tab.

## Depends on

- **The Tile: one drawing of an entry, shared by every Presentation**.

## Defaults chosen for you

- **The key.** Space, when the Search is empty, and `cmd-y` always. Space is a character in a Search, so it peeks only before anything is typed. `cmd-y` is Quick Look's other key in Finder.
- **The picture.** The cached thumbnail shows at once and is replaced by one full-resolution capture of that window. Only one full-resolution picture is held at a time, and it is dropped when the selection moves or the Lens closes.
- **A window that is not on screen** shows its Frozen thumbnail look, since the picture is of when it was last painted.
- **A minimized window** has no full-resolution capture and shows its thumbnail scaled up.
- **Where a window on a hidden workspace is shown.** At the frame it would have on the monitor that would show its workspace.
- **The panel.** One panel that ignores the mouse and never becomes key, above the Lens for the zoom and below it for `'follow`.
- **Timing.** About a quarter of a second, with the prototype's easing. With Reduce Motion on, it cross-fades.

## Done when

- [x] The peek key grows the selected Tile's picture to the window's frame, and the same key shrinks it back.
- [x] Arrow keys change the peeked window while peek is up.
- [x] Enter during peek focuses the window; Escape during peek returns to the Lens.
- [x] The focused window is the same before, during and after a peek that is dismissed.
- [x] A window on a hidden workspace peeks with its Frozen look; a minimized window peeks from its thumbnail.
- [x] `peek = 'follow` on a strip shows the selection under the panel.
- [ ] The pull request shows peek in the grid, the strip and `overview`, and says how long a full-resolution capture took on the build machine's display.

## Built

`peek` is Lens-only, runs alone, and is shipped on Space and cmd-y. Both Swift
and Nickel reject mixed command lists, including inactive profiles. An empty
visible Search accepts an unmodified peek key; typed or recalled text keeps
Space as text. Escape is intercepted before the input-state branches, so a
Search-starting list takes three Escapes when zoomed. Opening keys are replayed.
Other actions keep their selected/marked targets and Hold release behavior.

The session publishes `peekedId`; a single non-key, mouse-transparent panel draws
its cached picture at `miniatureWindowFrame`, then one asynchronous full-size
capture for a non-Frozen window. Frozen and minimized entries keep their cached
look; a missing picture gets an app icon on a plate. Selection changes discard
old full-size images and late replies. The picture follows keys, Search, grouping
and removal. Zoom blocks pointer selection; follow permits it. Miniatures keeps
its layout cells when a closed entry leaves the selectable results, so closing
the last matching window fades peek without closing the Lens.

The prototype’s ring, corners, shadow, label, timings and whole-panel dimming are
built, with cross-fades for Reduce Motion. The label stays below the real frame;
for a full-height frame it can fall outside the screen. `peek = 'follow` starts
under the panel without dimming, ring or label, and consumes peek keys without
changing pointer state. Miniatures uses zoom even when follow is configured.
Follow waits until the Lens is visible and stays below the separate list/grid legend.
Trace text and JSON report the peeked id and latest capture latency.

**Default changed: The key (Cmd-Tab Hold only).** Cmd-Space opens Spotlight before
WinMux sees it. A Cmd-Tab Hold therefore peeks with cmd-y alone, under the builder
ruling’s fallback. Space remains shipped and local in every Presentation; it is
never registered as a system-wide hotkey. The routing still supports invoking-
modifier subtraction when the system delivers the key.

Decided: The field is `peek`, and its default is `zoom`; miniatures silently uses zoom.

Decided: Lens-key removal uses `[]`; the default-config guide reserves
`without-bindings` for mode bindings and documents the Lens recipe separately.

Decided: Keep the assigned display unchanged. The 1920×1080 figures below are
requested capture output sizes on the fixed 1280×720, 1× virtual display, not a
native 1080p or Retina measurement. The full-frame source windows were 1280×690,
excluding the menu bar. Five samples per app and output size, after warming:

| App | Output | Median | Range |
| --- | --- | --- | --- |
| Safari | 1280×720 | 19.072 ms | 17.261–23.745 ms |
| Safari | 1920×1080 | 19.323 ms | 18.211–25.487 ms |
| Zed | 1280×720 | 18.750 ms | 17.317–20.880 ms |
| Zed | 1920×1080 | 18.539 ms | 17.859–20.050 ms |

Host and pinned-toolchain guest `make check` pass: 1,216 Swift, 77 Rust/helper and
75 Python tests, with no skips. GitHub CI is the driver’s separate merge gate.

The standing-desk runs cover grid grow/shrink and following, empty/text Search,
three Escapes, held Cmd-Y/Tab/release, Enter, Summon, close, Frozen and minimized
pictures, missing-thumbnail icon fallback, native Reduce Motion, overview and follow.
The temporary guest Reduce Motion preference was restored after its recording. The same no-peek script passes on the base and
feature builds. Proof tools are in `.scratch/winmux-fork/proofs/peek/`.
**Overview draws a workspace not yet shown at the wrong positions** and
**Floating picture Tiles fall back after an app resizes its windows** remain
unchanged; peek uses their existing frame helper too.

The final-commit pull-request demos and publishing belong to the driver.

### Checks for Prateek

- [ ] Installed-build behavior and real keyboard timing.
- [ ] Native 1920×1080 and Retina capture timings on real hardware.
- [ ] A second display and real sleep, wake and unlock.

## Sources

- [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html)
- The spike behind this issue read how AltTab previews a window. AltTab is GPL-3; nothing is copied from it.
