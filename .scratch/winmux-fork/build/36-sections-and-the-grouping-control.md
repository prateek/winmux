# Sections, and a control to change the grouping

Part of {{UMBRELLA}}.

## What to build

A Lens has a `sections` field (`'none`, `'workspace`, `'project`, `'monitor`, `'app`, default `'workspace`). The contract accepts it and nothing draws it. This issue draws sections in the grid and the list, lets each Presentation arrange them its own way, and lets the person change the grouping while the Lens is open.

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
- **The look is the prototype's**: [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html), the Sections switches and the control above the panel.

## Not in this issue

- A new grouping value. The five the contract has are the set.
- Sections in the strip or in `'miniatures`.
- Collapsing or hiding a section.

## Depends on

- **The `'grid` Presentation: every match at once, sized to fit**.

## Defaults chosen for you

- **Memory.** A grouping changed while the Lens is open lasts until the Lens closes. The next opening uses the config, or the `--sections` it was opened with.
- **What the control cycles through.** `'none`, `'workspace`, `'app`, then `'project` and `'monitor` when there is more than one of each.
- **Section order.** Workspace sections in workspace order with the focused one first; app sections by the Lens's sort order of their first window.
- **Arrow keys** move to the nearest Tile across section boundaries. The `'miniatures` setting `arrow-keys = 'by-workspace` is not copied here.
- **Events.** Changing the grouping emits no `lens-opened` or `lens-closed` pair, as changing the Search does not.

## Done when

- [ ] A grid Lens with `sections = 'workspace` draws labelled sections, and the focused workspace's is first and marked.
- [ ] `grid.sections-arrangement` takes its three values and each draws as the prototype shows.
- [ ] A list Lens draws a header above each section.
- [ ] `winmux lens <name> --sections app` opens grouped by app without changing the config.
- [ ] `cmd-g` and a click on the header control both change the grouping, and the selection stays on its window.
- [ ] `sections` on a `'miniatures` Lens still fails at load.
- [ ] The pull request shows each arrangement on the staged desk.

## Sources

- [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html)
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
