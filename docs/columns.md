# Fixed Columns

A workspace with Columns has a fixed number of positions across its monitor. Each position keeps its width when empty. A Column can hold one window, a tab group, or splits. Columns are off by default.

## Enable Columns on a workspace

```nickel
let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  columns.count = 'off,
  workspace.Demo.columns = {
    count = 3,
    widths = [1/4, 1/2, 1/4],
  },
}) | W.Config
```

This enables Columns only on the workspace named `Demo`. Workspace names refer to existing or subsequently created workspaces; the record does not create a workspace. Omitting `widths` gives equal widths. Widths must be positive, and their length must equal the resolved count. Values that do not sum to 1 are normalized proportionally, with a warning from `winmux config check` and when loading the config.

## Defaults and overrides

```nickel
let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  columns = {
    count = 3,
    widths = [1/3, 1/3, 1/3],
    width-presets = [1/3, 1/2, 2/3],
    when.default.widths = [1/4, 1/2, 1/4],
    when.travel.count = 4,
  },
  workspace.Demo.columns = {
    count = 2,
    widths = [1/2, 1/2],
    when.default.widths = [1/3, 2/3],
  },
}) | W.Config
```

Settings resolve field by field, in this order: `columns`, `columns.when.default`, `workspace.<name>.columns`, then `workspace.<name>.columns.when.default`. Only the `default` profile matches. Other profile records load but do not apply. `width-presets` belongs only to top-level `columns`; putting it under a workspace or any `when` record is an error. The default presets are 1/3, 1/2 and 2/3.

A reload resets current widths to the declared widths. Lowering the count folds the extra Columns' windows into the retained Columns' tab groups. Setting `count = 'off` restores ordinary tree tiling.

## Placement, movement and focus

New tiling windows use the nearest empty Column from the focused one, with ties going left. When all Columns are occupied, arrivals join the focused Column as a tab group. When focus is elsewhere, placement uses the most recently used Column. The ordinary automatic tab-group arrival setting does not override this behavior.

Closing a window leaves a gap rather than shifting its neighbours. `focus left` and `focus right` skip empty Columns. A focused empty Column has a faint outline and receives the next arrival. The user command for selecting an empty Column belongs to **Column Policy hooks and Column commands**.

`move left` and `move right` move the focused window across a Column boundary. An empty neighbour takes it alone; an occupied neighbour takes it into a tab group. Movement within a split keeps the ordinary tree behavior. Swapping Columns exchanges their positions; swapping within a Column keeps its position.

At workspace edges, the default move stops. `--boundaries-action fail` returns failure for command fall-through; `create-implicit-container` stops because Columns keep the root horizontal. `--boundaries all-monitors-outer-frame` can move to the next monitor. The same boundary actions apply at a Column's top and bottom.

## Widths

`resize width +40` on a window alone in its Column changes that Column's width. Its other Columns absorb the change in proportion to their widths, including empty Columns. Drag the faint divider at a Column boundary, or a window's edge at one, to use the same proportional operation and preview, including beside an empty Column. The dragged edge follows the pointer. The dividers are left out while the workspace has a floating or fullscreen window, so they never cover one; a window's edge still resizes its Column then. Resizing a split uses the ordinary sizing inside that Column. The minimum Column width is 80 points; when the monitor or the initial width ratios cannot fit every minimum, resizing uses equal fractions.

`balance-sizes` returns Columns to their declared widths and balances splits inside them. Width fractions survive a monitor size change, and gaps remain reserved beside empty Columns.

Width presets and explicit fractions use the same proportional operation. Stepping forward selects the smallest preset above the current width; stepping backward selects the largest below it. Both wrap. The `column-width` command that exposes preset stepping belongs to **Column Policy hooks and Column commands**.
