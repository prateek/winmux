# The Search match highlighted, and window controls on a Tile

Part of {{UMBRELLA}}.

## What to build

Two parts of the Tile that make a Lens quicker to read and to act in.

- **The match.** Typing a Search narrows a Lens, and nothing shows why an entry matched. This issue highlights the matched text in each Tile's title.
- **Window controls.** A Lens can close a window with `cmd-w`. With a mouse there is nothing to click. This issue shows close, minimize and fullscreen buttons on the Tile under the pointer.

## Decisions

- **The highlight marks the characters the Search matched**, in the title and in the app name where that is what matched. It uses the spans the existing matcher (`LensSearch.swift`) already computes or can report; ranking does not change.
- **The controls appear on the Tile under the pointer** and nowhere else, at the picture's top-left corner, in the order and colours of a window's own buttons.
- **Each control runs the command the keyboard would.** Close runs `close`, minimize runs `macos-native-minimize`, fullscreen runs `macos-native-fullscreen`, each on that Tile's window. A failed command leaves the Tile in place, as **`close` reports success on a window with no close button** decides for `close`.
- **A click on a control does not select or commit.** A click anywhere else on the Tile does what it does today.
- **Text Tiles and miniatures have no controls.** There is no room on a row or on a miniature.
- **The look is the prototype's**: [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html). Type in its Search box, and hover a Tile.

## Not in this issue

- A change to how Search ranks or what it matches.
- A quit-app control.
- Dragging a Tile.

## Depends on

- **The Tile: one drawing of an entry, shared by every Presentation**.

## Defaults chosen for you

- **A control whose command cannot apply** is hidden, such as close on a window with no close button.
- **After a control closes a window**, the Lens stays open and the layout re-flows.
- **The highlight colour** is the prototype's, checked for contrast in light and dark.

## Done when

- [ ] Typing a Search highlights the matched characters in every remaining Tile, in the list, the strip and the grid.
- [ ] Hovering a Tile in the grid or the strip shows three controls; moving off hides them.
- [ ] Each control acts on its own Tile's window, whichever Tile is selected.
- [ ] A click on a control does not close the Lens.
- [ ] A matcher test covers the reported spans for a prefix, a mid-word and a multi-word Search.

## Sources

- [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html)
