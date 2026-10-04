# Peek: see the selected window at full size before switching

Part of {{UMBRELLA}}.

## What to build

A thumbnail answers "which window is this" most of the time. When two windows look alike at thumbnail size, the person has to switch to find out. Peek shows the selected window at its real size, in its real place, without switching to it. It is Quick Look for windows.

**Blocked on Prateek.** He asked for a Quick Look style animation and to understand the design before agreeing to it. The design below is the prototype's and he has not confirmed it. Do not build until this issue says he has.

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

- [ ] Prateek has confirmed the design, and this issue says so.
- [ ] The peek key grows the selected Tile's picture to the window's frame, and the same key shrinks it back.
- [ ] Arrow keys change the peeked window while peek is up.
- [ ] Enter during peek focuses the window; Escape during peek returns to the Lens.
- [ ] The focused window is the same before, during and after a peek that is dismissed.
- [ ] A window on a hidden workspace peeks with its Frozen look; a minimized window peeks from its thumbnail.
- [ ] `peek = 'follow` on a strip shows the selection under the panel.
- [ ] The pull request shows peek in the grid, the strip and `overview`, and says how long a full-resolution capture took on the build machine's display.

## Sources

- [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html)
- The spike behind this issue read how AltTab previews a window. AltTab is GPL-3; nothing is copied from it.
