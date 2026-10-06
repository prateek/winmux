# Sections, and a control to change the grouping

Part of {{UMBRELLA}}.

## What to build

A Lens has a `sections` field (`'none`, `'workspace`, `'project`, `'monitor`, `'app`, default `'workspace`). The grid and the list draw it. This issue draws sections in the grid and the list, lets each Presentation arrange them its own way, and lets the person change the grouping while the Lens is open.

## Decisions

- **The grid and the list draw sections.** `'miniatures` stays fixed on workspaces and rejects `sections`. The strip is one row and ignores it.
- **The default grouping is `'workspace`**, as the contract already says. The focused workspace's section comes first and is marked as the one the person is on.
- **How sections share the space is set per Presentation**, in that Presentation's block:
  - `grid.sections-arrangement = 'flow`, the default: sections run on in the same rows, each labelled where it starts.
  - `'rows`: each section starts its own row.
  - `'columns`: each section is a column, side by side.
  - The list has one arrangement: a header row above each section.
- **Three ways to set the grouping**, most specific last:
  1. In the config, as `sections` on the Lens.
  2. Per invocation: `winmux lens <name> --sections <value>`, beside `--presentation`.
  3. While the Lens is open: a control in the panel's header shows the grouping and changes it on a click, and a Lens action `sections next` cycles it. `sections <value>` sets one.
- **The default key is `cmd-g`**, bound to `sections next` in the Lens's `keys`, where it can be changed like any other key.
- **Changing the grouping keeps the selection** on the same window and re-lays the Tiles.
- **The look is the prototype's**: [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html), the Sections switches, with the control inside the panel's Search row so every segment can receive clicks.

## Not in this issue

- A new grouping value. The five the contract has are the set.
- Sections in the strip or in `'miniatures`.
- Collapsing or hiding a section.

## Depends on

- **The `'grid` Presentation: every match at once, sized to fit**.

## Defaults chosen for you

- **Memory.** A grouping changed while the Lens is open lasts until the Lens closes. The next opening uses the config, or the `--sections` it was opened with.
- **What the control cycles through.** `'none`, `'workspace`, `'app`, then `'project` and `'monitor` when there is more than one of each.
- **Section order.** Workspace, project and monitor sections in their opening snapshot order, with the focused one first and marked; app sections by the Lens's ranked order of their first window. Unknown workspace entries form a final "No workspace" section.
- **Arrow keys** move geometrically by row across section boundaries: left/right use the same top or overlapping vertical span; up/down use the nearest row, preferring the same column when applicable. The `'miniatures` setting `arrow-keys = 'by-workspace` is not copied here.
- **Events.** Changing the grouping emits no `lens-opened` or `lens-closed` pair, as changing the Search does not.

The `sections` command is session-local and never closes a Lens. It needs no window target,
works on empty results, and exits 2 with "No Lens is open" when closed. Grouping changes and
Presentation changes retain the selected window; Search selects the best-ranked match even
in a later section. Headers cannot be selected. `--sections` needs a named Lens or `--filter`,
refuses resolved miniatures, and is accepted and ignored by a strip until list conversion.

The control shows the opening's cycle and any explicitly selected value outside it, plus the
first key bound to `sections next`. It retains Search focus and a Hold. The grid has a 644 scaled
point minimum width for three segments, plus 68 per extra segment; the list retains at least 760.
A sections-only key is omitted in strips and miniatures: Cmd-Tab followed by `g`, `h` converts to
a list with Search "gh"; another held `g` changes grouping. In a list or grid, held "log" searches
"lo" and changes grouping. Grouping lasts until close and is not remembered for the next opening.

All grid arrangements fit every Tile and header without a floor or paging, including twenty
app sections. Headers truncate and shrink with the chrome; very many columns become unreadable
rather than switching arrangements. Labelled arrangements use common row slots for oversized
windows, retaining their real picture sizes and geometric arrow rows. The original unlabelled layout remains with `sections = 'none`.

## Done when

- [x] A grid Lens with `sections = 'workspace` draws labelled sections, and the focused workspace's is first and marked.
- [x] `grid.sections-arrangement` takes its three values and each draws as the prototype shows.
- [x] A list Lens draws a header above each section.
- [x] `winmux lens <name> --sections app` opens grouped by app without changing the config.
- [x] `cmd-g` and a click on the header control both change the grouping, and the selection stays on its window.
- [x] `sections` on a `'miniatures` Lens still fails at load.
- [x] The pull request shows each arrangement on the staged desk.

## Sources

- [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html)
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)

## Prateek's checks

- [ ] Installed dogfood build.
- [ ] Monitor grouping on a second display.
- [ ] Real sleep, wake and unlock.
