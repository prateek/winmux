# Fixed Columns: slots, the count invariant, Width presets

Part of {{UMBRELLA}}.

## What to build

A workspace can be given a fixed number of Columns. Each Column keeps its position and width whether or not it holds a window, and the count holds no matter how a window gets onto the workspace. Column widths are fractions of the workspace width that can be stepped through Width presets or resized freely. This issue builds the layout model, the width handling and the built-in placement; the config hooks and the Column commands come in **Column Policy hooks and Column commands**.

## Decisions

**Where a Column lives in the tree**

- A Column is a child of the workspace's root container, and that root is `h` orientation with `tiles` layout. No new `Layout` case is added; a Column is marked by a per-workspace setting or by data on the node, not by a tree type.
- Columns belong to the workspace. Switching workspace changes every Column at once.
- A Column holds any arrangement: one window, a tab group, or splits in either direction, side by side included.
- Normalization (flatten, and opposite orientation for nested containers) leaves Column nodes alone and still applies inside them.

**Positional Columns**

- Each Column keeps its x-range and its width when it is empty. With one window on a three-Column workspace, the window sits in its Column and the other two Columns show the desktop.
- Closing a window leaves its Column empty. Nothing moves over to fill it.
- The tree cannot hold an empty container, so each root child carries a slot index. Layout places a root child by its slot index and the stored widths, not by its position in the children list.
- `focus left` and `focus right` skip empty Columns.
- An empty Column can still be the focused Column. It is drawn with a faint outline, and the next window placed in the focused Column lands there. The command that focuses an empty Column is in **Column Policy hooks and Column commands**; the model and the outline are here.

**The count is an invariant**

- The Column count holds on every path that puts a window on the workspace: a new window, `move`, `move-node-to-workspace`, drag and drop, closed-window-cache restore and `flatten-workspace-tree`. The paths that reuse new-window binding (floating to tiling, leaving native fullscreen or minimized) are covered too.
- A Column-invariant pass runs after `normalizeContainers` on every refresh, for every workspace with Columns on. It is idempotent.
- The pass forces the root to `h` and `tiles`.
- The pass counters flatten replacing the root. Today, a root whose only child is a container is replaced by that child, so a workspace with one occupied Column holding a tab group or a split ends up with a `v` or tab-group root. Either exempt the root from that flatten while Columns are on, or have the pass wrap it again.
- The pass counters the paths that wrap the root in a new root: `move` at the workspace boundary, insertion after a tab group, and `workspaceSiblingInsertionRoot`.
- The pass folds any root child beyond the count into a Column, using the built-in placement below.
- The pass re-applies the stored width fractions to the root children's weights.
- The `squeeze` Overflow policy action is the only way to exceed the count. It is built in **Column Policy hooks and Column commands**.

**Built-in placement**

- A new tiling window goes to the nearest empty Column.
- When no Column is empty, the window joins the focused Column as a tab group. When focus is not on this workspace's tiling tree, it joins the most recently used Column instead.
- `move left` and `move right` that cross a Column edge: an empty neighbour takes the window; an occupied neighbour takes it into a tab group; at the workspace edge the move stops. Inside a Column, `move` behaves as it does today.
- Closing a window runs no placement.

**Widths**

- Column widths are fractions of the workspace width that sum to 1. They are stored per workspace and converted to point weights before every layout. The tree's weights are absolute points and `layoutTiles` spreads any difference in equal amounts, so fractions kept only as weights drift when the monitor size changes or a Column empties. `AgentSizing.swift` already turns ratios into weights and is the pattern to follow.
- `widths` in the config gives the starting widths as a list of fractions. A list that does not sum to 1 is normalized proportionally, with a warning when the config loads.
- `width-presets` in the config is the list of Width presets.
- Setting a Column to a Width preset or to an explicit fraction makes its neighbours give up or take space in proportion to their widths, so the total stays 1. This issue builds that operation; the `column-width` command that calls it is in **Column Policy hooks and Column commands**.
- Free `resize` and divider drag are allowed, down to a minimum Column width. Width presets are stops, not limits.
- `resize` on a window that is alone in its Column resizes the Column. `resize` on a window inside a split resizes within the Column.
- `balance-sizes` resets the Column widths to the declared `widths` and balances sizes inside each Column.

**Config shape and precedence**

- The settings are read from four record paths, least specific first: `columns`, then `columns.when.<profile>`, then `workspace.<name>.columns`, then `workspace.<name>.columns.when.<profile>`.
- The most specific path wins field by field. A hook definition is replaced whole, never merged.
- The fields are `count`, `widths` and `width-presets`, plus the two hook fields that **Column Policy hooks and Column commands** adds.
- The `when.<profile>` slot is part of the shape now. There is one implicit profile, `"default"`, and it is the only one that ever matches.
- `count` is a number or `'off`, and the default is `'off`. With `count` off the workspace uses plain tree tiling exactly as upstream does: no slot indexes, no invariant pass, no width re-application.
- The Columns settings arrive as part of the static config the `winmux-nickel` helper returns at load. WinMux resolves the precedence chain itself at runtime, per workspace.

**Where it lands in the code** (paths under `Sources/AppBundle/`)

- The invariant pass goes right after `rootTilingContainer.unbindEmptyAndAutoFlatten()` in `tree/normalizeContainers.swift`.
- Built-in placement branches in `bindingDataForNewTilingWindow` in `tree/NewWindowBinding.swift`. About 25 other files call `bind(to:)` directly and skip that function, which is why the invariant pass has to catch what they do.
- Width handling touches `layout/layoutRecursive.swift` (`layoutTiles`), `command/impl/ResizeCommand.swift`, `command/impl/BalanceSizesCommand.swift` and the divider drag under `mouse/resize/`.
- `split` refuses to run while flatten normalization is on, so build a split inside a Column the way `join-with` does, with a wrapper container.
- A tab group with one child is not a stable node: flatten collapses it. Nothing here may depend on a one-window tab group.
- In this codebase `stack-with` makes a tab group. Do not name anything in Columns "stack".

## Not in this issue

- **Column Policy hooks and Column commands** covers the `place`, `move-boundary` and `arrive` hooks, the `split`, `float` and `squeeze` Overflow policy actions, and the commands `focus-column`, `move-node-to-column`, `column-width`, `compact`, `list-columns`, `column-count` and `place --dry-run`.
- **Default config, Triggers, the `lens` leader mode, `subscribe` events** covers the `columns-changed` event and shipping `count` off by default.
- **Thumbnail cache and the `'miniatures` Presentation** covers drawing Columns in miniature.
- Deferred: Display profiles. That includes matching a profile to a display, resetting widths and re-flowing Columns when the profile changes, and any profile other than `"default"`.
- Deferred: trackpad gestures, including drag gestures with a ghost preview.
- Deferred: reading and switching Tabs inside windows. A tab group of windows inside a Column is in scope; it is the existing WinMux feature.

## Depends on

- Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`

## Open details

Settle each of these while building and note the choice in the PR.

- **Identifier spelling.** The tickets write `width-presets`, `tab-group` and `nearest-empty`; the config prototype writes `width_presets`, `'tab_group` and `'nearest_empty`. This issue uses the hyphenated spelling. Use whatever the shipped Nickel contract settles on, and use it for every Columns name.
- **Column index base.** No ticket says whether slot indexes start at 0 or 1. Upstream's workspace, tab and monitor numbers start at 1.
- **Minimum Column width.** The number was not decided. Upstream's resize floor is `minimumTiledResizeWeight`, 80 points, in `mouse/resize/TiledResizeConstraints.swift`.
- **Default `width-presets`.** The glossary gives 1/3, 1/2 and 2/3 as an example only.
- **`widths` left out, or the wrong length.** Not decided: what the starting widths are when `widths` is omitted, and what happens when its length differs from `count`.
- **Where `width-presets` can be set.** The Columns ticket calls `width-presets` a global list and `widths` a per-profile one. Not decided: whether `width-presets` can be overridden per workspace and per profile like the other fields, or is read only from `columns`.
- **Which Columns are "neighbours".** Not decided: whether a width change is absorbed by every other Column or only the adjacent ones.
- **Free resize.** Not decided: whether `resize` and divider drag on a Column take space from the other Columns in proportion, as a Width preset change does, or in equal amounts, as upstream `resize` does.
- **Stepping from a width that is not a preset.** Not decided: which preset `next` and `prev` pick after a free resize, and whether stepping wraps at the ends of the list.
- **Which child is the extra.** Not decided: when a path other than a new window leaves the root with more children than the count, which child the invariant pass folds and into which Column. The deferred Display profiles ticket says a dropped count folds the extra Columns' contents by `place`.
- **"Nearest" empty Column.** Not decided: what the distance is measured from (the focused Column is the likely reading) and how a tie breaks.
- **`move up` and `move down` at the top or bottom of a Column.** Upstream wraps the root in a new `v` root here. The invariant forbids that, and no ticket says what the move does instead.
- **`auto-add-new-windows-to-tab-group`.** Not decided: whether this upstream setting still applies inside a workspace with Columns on, or built-in placement replaces it.
- **Config reload.** Not decided: whether a reload resets each workspace's stored widths to the declared `widths`, and how existing windows are folded when a reload lowers the count.
- **Gaps and empty Columns.** Not decided: whether inner gaps are still reserved next to an empty Column.

## Done when

- [ ] With `count` off, the existing layout tests pass unchanged and layout is the same as upstream's.
- [ ] `winmux config check` accepts a config that sets `columns.count`, `columns.widths` and `columns.width-presets`, and a `workspace.<name>.columns` record overrides `columns` field by field for that workspace only.
- [ ] A `columns.when.default` record overrides `columns`, and a `when` record under any other profile name loads and never applies.
- [ ] `widths` that do not sum to 1 load with a warning and are normalized proportionally.
- [ ] On a three-Column workspace with one window, the window occupies only its Column's x-range and the other two Columns are empty.
- [ ] Opening a second and a third window fills the empty Columns. A fourth joins the focused Column as a tab group, and the root still has three children.
- [ ] Closing the only window in a Column leaves that Column empty, and no other window moves or changes width.
- [ ] With every window but one closed, and that one in a tab group or a split, the root is still `h` and `tiles` after a refresh.
- [ ] `move right` into an empty Column moves the window there. Into an occupied Column it joins a tab group. At the workspace edge it does nothing and the root is not wrapped.
- [ ] `move-node-to-workspace`, drag and drop, `flatten-workspace-tree` and closed-window-cache restore each leave the target workspace with no more root children than the count.
- [ ] `focus left` and `focus right` skip empty Columns.
- [ ] A focused empty Column shows a faint outline, and the next new window lands in it. Until `focus-column` exists, a test sets the focused Column directly.
- [ ] After the monitor's size changes, every Column has the same fraction of the width as before.
- [ ] Setting a Column to a Width preset changes its width to that fraction and the widths still sum to 1. Until `column-width` exists, a test calls the operation directly.
- [ ] `resize` on a window alone in its Column changes the Column's width and stops at the minimum. `resize` on a window inside a split leaves the Column's width alone.
- [ ] `balance-sizes` returns the Column widths to the declared `widths`.
- [ ] Unit tests in `Sources/AppBundleTests` cover the invariant pass, including the flatten-replaces-root case with several windows, which upstream's tests do not cover.

## Sources

- [Grilling: fixed Columns, Width presets and Overflow policy semantics](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/09-grilling-fixed-columns-model.md)
- [Research: WinMux layout engine seams for fixed Columns](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/04-research-layout-engine-for-columns.md)
- [Research 04: WinMux layout engine seams for fixed Columns (findings)](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/research/04-layout-engine-for-columns.md)
- [Prototype: config and scripting language](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/27-prototype-config-language.md)
- [Config language prototype](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/prototypes/27-config-language.html)
- [CONTEXT.md](https://github.com/prateek/winmux/blob/wayfind-fork/CONTEXT.md)
