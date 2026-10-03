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

Closing a window leaves a gap rather than shifting its neighbours. `focus left` and `focus right` skip empty Columns. A focused empty Column has a faint outline and receives the next arrival. Use `focus-column <n>` to select an empty Column.

`move left` and `move right` move the focused window across a Column boundary. An empty neighbour takes it alone; an occupied neighbour takes it into a tab group. Movement within a split keeps the ordinary tree behavior. Swapping Columns exchanges their positions; swapping within a Column keeps its position.

At workspace edges, the default move stops. `--boundaries-action fail` returns failure for command fall-through; `create-implicit-container` stops because Columns keep the root horizontal. `--boundaries all-monitors-outer-frame` can move to the next monitor. The same boundary actions apply at a Column's top and bottom.

## Widths

`resize width +40` on a window alone in its Column changes that Column's width. Its other Columns absorb the change in proportion to their widths, including empty Columns. Drag the faint divider at a Column boundary, or a window's edge at one, to use the same proportional operation and preview, including beside an empty Column. The dragged edge follows the pointer. The dividers are left out while the workspace has a floating or fullscreen window, so they never cover one; a window's edge still resizes its Column then. Resizing a split uses the ordinary sizing inside that Column. The minimum Column width is 80 points; when the monitor or the initial width ratios cannot fit every minimum, resizing uses equal fractions.

`balance-sizes` returns Columns to their declared widths and balances splits inside them. Width fractions survive a monitor size change, and gaps remain reserved beside empty Columns.

Width presets and explicit fractions use the same proportional operation. Stepping forward selects the smallest preset above the current width; stepping backward selects the largest below it. Both wrap. Use `column-width next`, `column-width prev` or `column-width 0.5`, including on a window in a vertical split where `resize width` cannot edit the Column.

## Policy hooks

Hooks are pure Nickel functions. `arrive` runs once on detection, before tiling placement; `place` runs whenever a window becomes a tiling window on a workspace. `move-boundary` decides horizontal movement into an occupied Column or across the workspace edge. Each receives a Window record, Filter context and array of Column records; `move-boundary` also receives `edge`, true at the workspace edge. Each Column has `index`, fractional `width`, `empty` and `windows` (Window records). Arrive sees the Columns on the detected workspace, before any routing.

```nickel
let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  columns.count = 'off,
  arrive = fun w ctx cols =>
    if w.app.bundleId == "com.example.Editor" then { workspace = "Writing", float = false }
    else {},
  workspace.Writing.columns = {
    count = 3,
    place = fun w ctx cols => { column = 'focused, overflow = 'tab-group },
    move-boundary = fun w ctx cols edge => {
      action = if edge then 'wrap else 'join,
      overflow = 'split,
    },
  },
}) | W.Config
```

`place` requires `column` and `overflow`. Targets are `'focused`, `'mru`, `'nearest-empty`, `'last`, or a positive index. An index greater than the configured count is an error and uses built-in placement. On an occupied target, `'tab-group` joins its tab group, `'split` wraps the contents and arrival in vertical tiles, `'float` floats the arrival, and `'squeeze` adds one extra Column on the right. Its fraction is `1 / (count + 1)`, taken proportionally from existing widths. Further squeeze arrivals share that extra Column. When it empties, the invariant removes it and restores declared widths. No other action exceeds the count.

`arrive` may return `workspace`, `float`, `column`, `overflow` and `run`, or `{}`. With no `column`, tiling arrivals fall through to the destination workspace's `place`. An explicit Column bypasses `place`; omitted Overflow policy is `'tab-group`. `float = true` skips `place`, and `float = false` overrides the Accessory floating default. On a workspace with Columns off, Arrive receives `[]`; Place and Move-boundary do not run.

The Window's `class` describes its binding default before Arrive: a regular tiling window is `tiled`, and an Accessory floating default is `floating`. Temporary holding containers do not change that argument.

Arrive also observes newly detected popups. An answer without `workspace`, `float` or `column` preserves their existing class and can still run commands.

Arrive replaces `[[on-window-detected]]`. The old key fails Nickel loading with an extra-field diagnostic. `winmux config convert` leaves the old callbacks as commented Arrive migration suggestions and warns that their matching and command order need translation; it does not silently preserve the callbacks. Define a single Arrive function with the desired branches instead.

Into an occupied neighbour, Move-boundary returns `'join` (with optional `overflow`) or `'swap`. At an edge it returns `'stop`, `'wrap`, `'next-workspace` or `'next-monitor`. An empty neighbouring Column accepts the move without calling the hook. If `overflow` is omitted for a join, Place supplies it. Without a Move-boundary hook, occupied moves join using Place's Overflow policy and the existing `--boundaries` / `--boundaries-action` options govern workspace edges.

Place and Move-boundary resolve over `columns`, `columns.when.default`, `workspace.<name>.columns`, then `workspace.<name>.columns.when.default`. A more specific function replaces a less specific function whole. Other profiles remain inactive.

All three result records may include `run`, an array of config-allowed command strings. Commands run after placement, target the hook's window, and execute in order. For a routed Arrive, Place's commands run before Arrive's commands. Summon runs Place once per marked window, never Arrive. Floating-to-tiling changes, minimized/native-fullscreen restoration, closed-window-cache restoration, workspace/monitor/project transfers and arriving drag-and-drop windows also use Place. Moving within a Column and closing a window do not call it.

Every hook has a 50 ms deadline. Timeout, missing helper, raised error or invalid result uses built-in placement/movement. The error is logged and stored as `last-error` in `winmux config status`, without a notification per call. `winmux config check` smoke-runs every configured hook twice, with populated and null context windows, and rejects invalid result contracts with Nickel's diagnostic.

## Column commands

| Command | Behavior and flags |
| --- | --- |
| `focus-column <n>` | Focus an occupied or empty Column; optional `--workspace <name>`. |
| `move-node-to-column <n>` | Move the window, joining an occupied target's tab group; optional `--window-id <id>`. |
| `column-width next\|prev\|<fraction>` | Set the focused Column's width proportionally; optional `--window-id <id>` targets that window's Column. Fractions are strictly between 0 and 1. |
| `compact` | Pack occupied Columns toward Column 1, keeping widths with slots; optional `--workspace <name>`. |
| `list-columns [--json]` | List the focused workspace, or `--workspace <name>`. JSON keys: `index`, `width`, `empty`, `window-ids`. |
| `column-count <n>\|off` | Override the focused workspace's count until reload; optional `--workspace <name>`. Lowering folds contents; `off` restores ordinary tree tiling. |
| `place --dry-run --window-id <id> [--json]` | Explain placement onto the currently focused workspace, without moving the window or executing `run`. The Lens Summon landing spot uses this same read-only decision. |

Commands exit 0 on success, 1 on runtime failure (including a missing server or a failed dry-run hook), and 2 on bad usage. Focus/move indices beyond the configured count exit 2. An actual arrival still uses built-in placement when its hook fails. A reload resets count overrides and current widths to configured values.
