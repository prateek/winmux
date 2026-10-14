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

- **Hover also selects**, once **Hover selects in the strip and the grid** lands, so the Tile with the controls is the selected one. A pointer that has not moved shows no controls.
- **A control whose command cannot apply** is hidden, such as close on a window with no close button.
- **After a control closes a window**, the Lens stays open and the layout re-flows.
- **The highlight colour** is the prototype's, checked for contrast in light and dark.

## Done when

- [x] Typing a Search highlights the matched characters in every remaining Tile, in the list, the strip and the grid.
- [x] Hovering a Tile in the grid or the strip shows three controls; moving off hides them.
- [x] Each control acts on its own Tile's window, whichever Tile is selected.
- [x] A click on a control does not close the Lens.
- [x] A matcher test covers the reported spans for a prefix, a mid-word and a multi-word Search.

## Build details

- Search spans come from the tier and field that scored each word, as character offsets in the original displayed string. Several words' ranges merge; workspace/project matches mark no displayed text. Ranking tests remain unchanged. Matcher regressions assert original substrings for prefix, mid-word, multi-word title/app, contains, initials, subsequence, workspace-only and length-changing lowercase.
- The session caches each applied Search's spans. Explicit Search applies at opening in every Presentation, including strips, which used to ignore it until `/`. A remembered Search still never filters a strip at opening, whatever its `starts-in`. Inline Search has no highlight. An empty title uses the app name's ranges.
- Attributed text runs use the prototype's `#ffd54a` background and `#111111` foreground, with 13.37:1 contrast in light and dark. They preserve truncation and omit the prototype's rounded corners. Card bars, text Tiles, list rows and the selection footer draw the runs. Picture Tiles have no title bar, as `.tile.k-picture .bar { display: none }` in the prototype specifies; their strip/grid highlight is the footer's. Miniatures are unchanged.
- Picture/card controls share pure picture and control rectangles with hit testing, including the selected Tile's lift. They scale from the prototype's 16-point circles, 6-point gaps and 8-point insets. Uniform shrinking stops at an actual 10-point diameter; below that, no controls draw. Hidden controls keep their slots.
- Hover is a window id separate from selection. One pointer-motion decision feeds hover and selection. A resting pointer reveals nothing until it moves more than one point; gaps, chrome and outside-frame movement clear hover while preserving selection. Key/wheel steps retain the hovered controls. Results removal, Presentation conversion and dismissal clear hover. Every control re-arms the pointer, preventing a following close on a Tile that slid under it.
- Whether each window button is there and enabled is read only for a Lens, in the same AX round-trip as its Filter record, and carried beside it; the schema is unchanged and other record readers pay nothing. The green control needs an enabled full-screen button, or a zoom button with the full-screen subrole. Minimize hides on minimized and native-fullscreen windows, and minimize and fullscreen on a hidden app's windows; native fullscreen still offers its toggle. Controls use the shared command/restoration path with one explicit window id, ignoring marks, selection and held modifiers. They never commit or dismiss; after a control succeeds the open Tile is read again, so a minimized Tile freezes and loses its minimize control, and a fullscreen one loses minimize. Failures use the `lens` unified log. The hosting view accepts the first mouse click after native fullscreen takes key focus.
- Host and pinned-version guest checks cover matcher spans, cached/applied Search, existing hit cases and ordinary clicks, strip/grid control geometry, narrow pictures, hidden slots, hover lifetime, targeting, native fullscreen, failure and trace behavior. Disabling spans, hover, first-click acceptance or the physical size floor makes the corresponding regressions fail.
- The four-window standing-desk debug run checked typed list/card/text highlights, an explicit held-strip Search, both appearances, inline exclusion, resting/moving/gap/outside hover, all three controls on an unselected Tile, marked-window isolation, minimize's immediate badge and missing slot, close/reflow and pointer suppression, native fullscreen on/off, held-strip release and a missing close button. The same script against an untouched base and the feature preserves strip/grid picture commits and Search order. Native fullscreen fills its Space behind the still-open Lens; first-click acceptance keeps its follow-up control usable. The trace reads the hovered window id in text and JSON.

## Checks for Prateek

- [ ] Installed-build behavior.
- [ ] A second display.
- [ ] Real sleep, wake and unlock.

The builder publishes no release. The driver cuts the dogfood release after landing.

## Sources

- [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html)
